# Scenario 2: Bastion + NAT + Nginx Reverse Proxy

Infrastructure avec un serveur bastion public et un JumpServer privé.

## Architecture

- **Bastion (public)** : 
  - NAT server pour permettre au JumpServer privé d'accéder à Internet
  - Reverse proxy Nginx vers le JumpServer privé
  - Point d'entrée SSH
  - IP publique + IP privée (${var.bastion_private_ip})

- **JumpServer (privé)** :
  - Pas d'IP publique
  - Accessible uniquement via le réseau privé
  - IP privée (${var.jumpserver_private_ip})
  - Accès Internet via NAT du bastion

## Déploiement

```bash
cd scenario2
terraform init
terraform plan
terraform apply
```

## Accès

1. **SSH vers le bastion** :
   ```bash
   ssh root@<BASTION_PUBLIC_IP>
   ```

2. **SSH vers JumpServer depuis le bastion** :
   ```bash
   ssh root@10.40.0.21
   ```

3. **Web JumpServer via reverse proxy** :
   ```
   http://<BASTION_PUBLIC_IP>
   ```

## Configuration

Le bastion configure automatiquement :
- IP forwarding
- iptables NAT (MASQUERADE)
- Nginx reverse proxy vers le JumpServer privé

## Sécurité

- JumpServer isolé (pas d'IP publique)
- Firewall restrictif sur le JumpServer (accès réseau privé uniquement)
- Tout le trafic passe par le bastion
