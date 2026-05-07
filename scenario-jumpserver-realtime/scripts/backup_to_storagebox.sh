#!/bin/bash
# Script de sauvegarde automatique PostgreSQL et Redis vers Storage Box (pour serveur data avec Docker)

# Installation automatique des outils nécessaires si absents
if ! command -v pg_dump >/dev/null; then
  apt update && apt install -y postgresql-client
fi
if ! command -v docker >/dev/null; then
  apt update && apt install -y docker.io
fi

DATE=$(date +%F_%H-%M)
BACKUP_DIR="/data/storagebox"
REDIS_PASSWORD="redisP@ssword@@@1"  # Mets ici le vrai mot de passe Redis

# Sauvegarde PostgreSQL (depuis le conteneur Docker)
docker exec jms_ext_postgresql pg_dump -U postgres jumpserver > $BACKUP_DIR/jumpserver_${DATE}.sql

# Sauvegarde Redis (depuis le conteneur Docker, avec mot de passe)
docker exec jms_ext_redis redis-cli -a "$REDIS_PASSWORD" save
# Copie le dump.rdb depuis le conteneur
if docker cp jms_ext_redis:/data/dump.rdb $BACKUP_DIR/redis_${DATE}.rdb; then
  echo "Sauvegarde Redis OK"
else
  echo "Erreur : dump.rdb introuvable dans le conteneur Redis" >&2
fi

# Nettoyage des sauvegardes de plus de 7 jours (optionnel)
# find $BACKUP_DIR/jumpserver_*.sql -mtime +7 -delete
# find $BACKUP_DIR/redis_*.rdb -mtime +7 -delete


