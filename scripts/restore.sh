#!/bin/bash
# =============================================
# Script de Restauração — Docker Volume
# Disciplina: Infraestrutura e Serviços de TI
# =============================================

BACKUP_FILE=$1
NEW_VOLUME_NAME=${2:-"volume-restaurado"}
BACKUP_DIR="./backups"

if [ -z "$BACKUP_FILE" ]; then
  echo "Uso: ./restore.sh <arquivo-backup.tar.gz> [nome-volume-destino]"
  echo ""
  echo "Backups disponíveis:"
  ls -lh $BACKUP_DIR/*.tar.gz 2>/dev/null
  exit 1
fi

echo "========================================"
echo "Iniciando restauração..."
echo "Arquivo: $BACKUP_FILE"
echo "Volume destino: $NEW_VOLUME_NAME"
echo "========================================"

# Criar novo volume
docker volume create $NEW_VOLUME_NAME

# Restaurar dados
docker run --rm \
  -v $NEW_VOLUME_NAME:/dest \
  -v $(pwd)/$BACKUP_DIR:/backup \
  alpine \
  tar xzf /backup/$(basename $BACKUP_FILE) -C /dest

if [ $? -eq 0 ]; then
  echo "Restauração concluída com sucesso!"
  echo "Volume '$NEW_VOLUME_NAME' está pronto para uso."
else
  echo "ERRO na restauração!"
fi
