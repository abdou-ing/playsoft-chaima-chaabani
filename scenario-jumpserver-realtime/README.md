# Scenario JumpServer Realtime (Active/Active App)

Ce dossier cree un nouveau scenario **sans modifier** `jumpserver-ha`.

Objectif:
- 2 noeuds JumpServer actifs derriere LB (`[0,1]`)
- 1 noeud dedie PostgreSQL + Redis en reseau prive
- Donnees partagees en temps reel entre les 2 noeuds applicatifs
- Pas de cron de synchronisation entre node1 et node2

## Architecture

- `hzn-jump-realtime-1` et `hzn-jump-realtime-2`: noeuds JumpServer
- `hzn-jump-realtime-data`: serveur dedie PostgreSQL + Redis
- `hzn-jump-realtime-lb`: load balancer public

Important:
- Les donnees runtime PostgreSQL/Redis restent sur disque local du noeud data.
- Storage Box peut servir aux backups, pas au data directory PostgreSQL runtime.

## Prerequis

- Terraform >= 1.5
- Reseau Hetzner prive existant
- Cle SSH Hetzner existante

## Deploiement

```bash
cd /home/chaima/playsoft/terraform/scenario-jumpserver-realtime
cp env/dev.tfvars.example env/dev.tfvars
# editer les mots de passe
terraform init
terraform plan -var-file=env/dev.tfvars
terraform apply -var-file=env/dev.tfvars
```

## Verification

```bash
terraform output load_balancer_public_ipv4
terraform output jumpserver_public_ips
terraform output data_node_public_ip
```

Tester HTTP LB:

```bash
LB=$(terraform output -raw load_balancer_public_ipv4)
curl -I http://$LB/ui/
```

Verifier config DB/Redis externe sur chaque noeud JumpServer:

```bash
ssh root@<jump_ip> "grep -E '^(DB_HOST|DB_PORT|DB_NAME|DB_USER|REDIS_HOST|REDIS_PORT|REDIS_PASSWORD)=' /opt/jumpserver/config/config.txt"
```

## Notes

- Cette approche est faible cout et corrige la derive de donnees du mode DB locale sur chaque noeud.
- Pour HA complete du stockage, il faudra separer PostgreSQL et Redis avec replication/failover dedie.

## Configuration sur les serveurs JumpServer (HA-2-jumpserver)

### 1) Forcer DB/Redis externe dans les fichiers de config

```bash
for F in \
	/opt/jumpserver/config/config.txt \
	/opt/jumpserver/config/.env \
	/opt/jumpserver-installer/config/config.txt \
	/opt/jumpserver-installer/config/.env \
	/opt/jumpserver-installer-v4.8.0/config/config.txt \
	/opt/jumpserver-installer-v4.8.0/config/.env
do
	[ -f "$F" ] || continue
	sed -i 's/^DB_HOST=.*/DB_HOST=10.40.0.13/' "$F"
	sed -i 's/^DB_PORT=.*/DB_PORT=5432/' "$F"
	sed -i 's/^REDIS_HOST=.*/REDIS_HOST=10.40.0.13/' "$F"
	sed -i 's/^REDIS_PORT=.*/REDIS_PORT=6379/' "$F"
done
```

### 2) Redemarrer les services JumpServer

```bash
JMSCTL="$(find /opt -maxdepth 4 -type f -name jmsctl.sh 2>/dev/null | head -n 1)"
echo "JMSCTL=$JMSCTL"
if [ -n "$JMSCTL" ]; then
	cd "$(dirname "$JMSCTL")"
	./jmsctl.sh down || true
	./jmsctl.sh up -d
else
	echo "jmsctl.sh introuvable"
fi
```

### 3) Verifier l'etat

```bash
./jmsctl.sh start
docker ps --format 'table {{.Names}}\t{{.Status}}'
```

### 4) Verifier la config appliquee dans le conteneur

```bash
/opt/jumpserver-installer-v4.10.16# docker inspect jms_core --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^(DB_HOST|DB_PORT|DB_NAME|DB_USER|REDIS_HOST|REDIS_PORT)='
```

## Storage Box: verification et montage

### Connexion et creation du dossier backup

```bash
sftp u578218@u578218.your-storagebox.de
ssh u578650@u578650.your-storagebox.de
ls 
```

### Monter le Storage Box sur la VM data

```bash
bash /usr/local/bin/mount-storagebox.sh
mount | grep /data/storagebox
ls -lh /data/storagebox/
```

### Copier et executer le script de sauvegarde

```bash
ssh-keygen -f ~/.ssh/known_hosts -R ip
scp -i ~/.ssh/chaima_key ./scripts/backup_to_storagebox.sh root@65.21.253.74:/root/
chmod +x /root/backup_to_storagebox.sh
/root/backup_to_storagebox.sh
ls -lh /data/storagebox/
```

### Cron pour sauvegarde vers Storage Box

```bash
* * * * * /root/backup_to_storagebox.sh
```

## Object Storage + rclone (synchronisation)

### Installer et configurer rclone

```bash
apt install rclone
rclone config
```

Exemple de configuration du remote `hetzner-obj` (valeurs sensibles a remplacer) :

```text
Storage> 5
provider> 24
env_auth> 1
access_key_id> <REPLACE_ACCESS_KEY_ID>
secret_access_key> <REPLACE_SECRET_ACCESS_KEY>
region>
endpoint> https://hel1.your-objectstorage.com
location_constraint> eu-central
acl> 1
```

### Lancer la synchronisation

```bash
rclone sync /data/storagebox/ hetzner-obj:jumpserver-data/
rclone ls hetzner-obj:jumpserver-data/
```

Cron :

```bash
* * * * * rclone sync /data/storagebox/ hetzner-obj:jumpserver-data/ >> /var/log/rclone_sync.log 2>&1
```

### Lister et verifier les fichiers

```bash
sftp u578650@u578650.your-storagebox.de
cd backup
ls
```

Verifier un dump SQL (exemple) :

```bash
rclone copy hetzner-obj:jumpserver-data/jumpserver_2026-04-27_13-36.sql /tmp/
less /tmp/jumpserver_2026-04-27_13-36.sql
```

Supprimer un bucket complet si besoin (attention) :

```bash
rclone delete hetzner-obj:jumpserver-data
```

## Sauvegardes differentielle et Restic

### Rappel des types de backup

- Full backup: copie tout a chaque fois, lourd et lent.
- Differential backup: copie ce qui a change depuis le dernier full, restauration simple (full + dernier diff).
- Incremental backup: copie ce qui a change depuis la derniere sauvegarde, restauration plus longue.

Restic fait des snapshots incrementaux et dedupes automatiquement, avec chiffrement.

### Variables d'environnement Restic (remplacer les secrets)

```bash
export RESTIC_REPOSITORY="s3:https://hel1.your-objectstorage.com/jumpserver-data"
export RESTIC_PASSWORD="<REPLACE_RESTIC_PASSWORD>"
export AWS_ACCESS_KEY_ID="<REPLACE_ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<REPLACE_SECRET_ACCESS_KEY>"
```

### Commandes Restic utiles

Lister les snapshots :

```bash
restic snapshots
```

Restaurer le dernier snapshot :

```bash
restic restore latest --target /tmp/restic-restore
```

Verifier des donnees restaurees :

```bash
grep "user-1" /tmp/restic-restore/data/storagebox/jumpserver_*.sql
grep "user-2" /tmp/restic-restore/data/storagebox/jumpserver_*.sql
```

Execution automatique (exemple) :

```bash
/root/backup_to_objectstorage.sh >> /var/log/restic-backup.log 2>&1
```

Supprimer des snapshots par ID :

```bash
restic forget <SNAPSHOT_ID_1> <SNAPSHOT_ID_2> <SNAPSHOT_ID_3>
```

Nettoyer l'espace :

```bash
restic prune
```

Verifier :

```bash
restic snapshots
```
