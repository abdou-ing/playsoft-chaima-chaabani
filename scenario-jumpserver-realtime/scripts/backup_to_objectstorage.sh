#!/bin/bash
# Script de sauvegarde incrémentale des dumps vers l'Object Storage avec Restic

# Variables Restic (à adapter avec tes vraies clés)


BACKUP_DIR="/data/storagebox"

# Installation automatique de restic si absent
if ! command -v restic >/dev/null; then
  apt update && apt install -y restic
fi

# Initialisation du dépôt Restic (à faire une seule fois, laisse en commentaire après la première exécution)
# restic init

# Sauvegarde incrémentale vers l'Object Storage
restic backup "$BACKUP_DIR"

# Rétention : garder 7 sauvegardes quotidiennes et 4 hebdomadaires
restic forget --prune --keep-daily 7 --keep-weekly 4

echo "Backup Restic terminé à $(date)"