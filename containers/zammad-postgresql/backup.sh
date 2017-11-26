#!/bin/bash

set -e

function check_zammad_ready {
  until [ -f "${ZAMMAD_READY_FILE}" ]; do
    echo "waiting for install or update to be ready..."
    sleep 5
  done
}

function zammad_backup {
  TIMESTAMP="$(date +'%Y%m%d%H%M%S')"

  echo "${TIMESTAMP} - backuping zammad..."

  # delete old backups
  if [ -d "${BACKUP_DIR}" ] && [ -n "$(ls ${BACKUP_DIR})" ]; then
    find ${BACKUP_DIR}/*_zammad_*.gz -type f -mtime +${HOLD_DAYS} -exec rm {} \;
  fi

  # tar files
  tar -czf ${BACKUP_DIR}/${TIMESTAMP}_zammad_files.tar.gz ${ZAMMAD_DIR}

  #db backup
  pg_dump --dbname=postgresql://postgres@zammad-postgresql:5432/zammad_production | gzip > ${BACKUP_DIR}/${TIMESTAMP}_zammad_db.psql.gz
}

if [ "$1" = 'zammad-backup' ]; then

  check_zammad_ready

  while true; do
    zammad_backup

    # wait until next backup
    sleep ${BACKUP_SLEEP}
  done
fi

if [ "$1" = 'zammad-backup-once' ]; then
  check_zammad_ready

  zammad_backup
fi
