#!/bin/sh
# Nightly backup, run by the "backup" service: the database (pg_dump,
# custom format) and the backend's storage (photos, JWT keypair) into
# ./backups, keeping BACKUP_KEEP_DAYS days. Copy ./backups off this server
# too (docs/DEPLOY.md, "Backups"): a backup on the same disk dies with it.
#
#   docker compose -f docker-compose.prod.yml exec backup sh /backup.sh now
set -eu
umask 077

BACKUP_HOUR="${BACKUP_HOUR:-3}"
BACKUP_KEEP_DAYS="${BACKUP_KEEP_DAYS:-14}"
export PGPASSWORD="$POSTGRES_PASSWORD"

backup() {
    stamp=$(date +%Y-%m-%d_%H%M)
    pg_dump -h postgres -U hssan -d hssan_delivery -Fc -f "/backups/db-$stamp.dump.part"
    mv "/backups/db-$stamp.dump.part" "/backups/db-$stamp.dump"
    tar -czf "/backups/storage-$stamp.tar.gz.part" -C /storage .
    mv "/backups/storage-$stamp.tar.gz.part" "/backups/storage-$stamp.tar.gz"
    find /backups -type f \( -name 'db-*.dump' -o -name 'storage-*.tar.gz' \) \
        -mtime +"$BACKUP_KEEP_DAYS" -delete
    echo "$(date '+%F %T') backup $stamp done"
}

if [ "${1:-}" = now ]; then
    backup
    exit 0
fi

while :; do
    now=$(date +%s)
    next=$(date -d "today $BACKUP_HOUR:00" +%s)
    [ "$next" -gt "$now" ] || next=$(date -d "tomorrow $BACKUP_HOUR:00" +%s)
    sleep $((next - now))
    backup || echo "$(date '+%F %T') backup FAILED" >&2
done
