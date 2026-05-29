#!/bin/bash
# =============================================
# Script de Backup Automatizado — Docker Volume
# Disciplina: Infraestrutura e Serviços de TI
# =============================================

VOLUME_NAME="mysql-prod-data"
CONTAINER_NAME="mysql-funcional"
BACKUP_DIR="./backups"
DATE=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$BACKUP_DIR/backup-log.txt"

echo "========================================"
echo "Iniciando backup em: $DATE"
echo "========================================"

# Criar pasta de backup se não existir
mkdir -p $BACKUP_DIR

# --- BACKUP FÍSICO (tar.gz do volume) ---
echo "[$(date)] Iniciando backup tar do volume $VOLUME_NAME..." | tee -a $LOG_FILE

docker run --rm \
  -v $VOLUME_NAME:/source \
  -v $(pwd)/$BACKUP_DIR:/backup \
  alpine \
  tar czf /backup/volume-backup-$DATE.tar.gz -C /source .

if [ $? -eq 0 ]; then
  echo "[$(date)] Backup tar concluído com sucesso!" | tee -a $LOG_FILE
else
  echo "[$(date)] ERRO no backup tar!" | tee -a $LOG_FILE
fi

# --- BACKUP LÓGICO (mysqldump) ---
if docker ps | grep -q $CONTAINER_NAME; then
  echo "[$(date)] Container $CONTAINER_NAME encontrado. Iniciando dump SQL..." | tee -a $LOG_FILE

  docker exec $CONTAINER_NAME \
    mysqldump -uroot -proot123 --all-databases > $BACKUP_DIR/dump-$DATE.sql

  if [ $? -eq 0 ]; then
    echo "[$(date)] Dump SQL concluído!" | tee -a $LOG_FILE
  else
    echo "[$(date)] ERRO no dump SQL!" | tee -a $LOG_FILE
  fi
else
  echo "[$(date)] Container $CONTAINER_NAME não está rodando. Pulando dump SQL." | tee -a $LOG_FILE
fi

# --- REMOVER BACKUPS ANTIGOS ---
echo "[$(date)] Removendo backups com mais de 30 dias..." | tee -a $LOG_FILE
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
find $BACKUP_DIR -name "*.sql"    -mtime +7  -delete

# --- RESUMO FINAL ---
echo "========================================"
echo "Backups disponíveis em: $BACKUP_DIR"
ls -lh $BACKUP_DIR/*.tar.gz 2>/dev/null
ls -lh $BACKUP_DIR/*.sql    2>/dev/null
echo "========================================"
echo "[$(date)] Backup finalizado!" | tee -a $LOG_FILE
