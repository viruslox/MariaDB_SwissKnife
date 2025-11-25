#!/bin/bash

echo "This script performs and manteins database backup. All DBs if You given admin credentials."

CONFIG_FILE="mariadb.conf"

if [[ -f "./$CONFIG_FILE" ]]; then
    source "./$CONFIG_FILE"
else
    echo "[ERR]: Configuration file '$CONFIG_FILE' not found. Try re-run setup.sh."
    exit 1
fi

BACKUP_DIR="${BACKUP_DIR:-$HOME/db_backups}"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M)
DB_DUMP_MIN=${DB_DUMP_MIN:-5}
DB_DUMP_EXPIRE=${DB_DUMP_EXPIRE:-30}

MY_GZIP=$(which gzip)
if [[ ! -x "$MY_GZIP" ]]; then
    echo "[WARN]: 'gzip' not found. DB dumsps won't be compressed."
fi

## Database Discovery
# Note: we skip "information_schema"" & "performance_schema"
DB_LIST=$("$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -N -e "SHOW DATABASES" 2>/dev/null | grep -Ev "^(information_schema|performance_schema)$")

# If list is empty, then we don't have DB admin creds do we limit backup to the configured DB
if [[ -z "$DB_LIST" ]]; then
    DB_LIST="$DATABASE"
fi

## Database Dumps
for DB_NAME in $DB_LIST; do
    FILE_NAME="${BACKUP_DIR}/${TIMESTAMP}_${DB_NAME}.sql"
    echo -n "[INFO]: Taking dump of '$DB_NAME'"

    "$MYSQLDUMP" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" --single-transaction --routines --triggers --databases "$DB_NAME" > "$FILE_NAME"

    if [[ $? -eq 0 ]]; then
        echo "[INFO]: $DB_NAME dump saved in $FILE_NAME"
    else
        echo "[FAIL]: $DB_NAME dump has failed. Try to check for errors in  $FILE_NAME"
    fi
done

## Compress!
if [[ -x "$MY_GZIP" ]]; then
    echo "[INFO]: Compressing database dump(s)"

    find "$BACKUP_DIR" -maxdepth 1 -name "${TIMESTAMP}_*.sql" -type f | while read SQL_FILE; do
        echo -n "  Compressing $(basename "$SQL_FILE")... "
        "$MY_GZIP" -f "$SQL_FILE"
        echo "Done."
    done
fi

## Retention
BACKUP_COUNT=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "*.sql*" | wc -l)

if [[ "$BACKUP_COUNT" -gt "$DB_DUMP_MIN" ]]; then
    echo "[INFO]: File count ($BACKUP_COUNT) > Min ($DB_DUMP_MIN). Checking expiration..."
    CUTOFF_DATE=$(date -d "-$DB_DUMP_EXPIRE days" +%Y%m%d)
    find "$BACKUP_DIR" -maxdepth 1 -type f -name "*.sql*" | while read FILE_PATH; do
        FILENAME=$(basename "$FILE_PATH")
        FILE_DATE_STR=$(echo "$FILENAME" | cut -d'_' -f1)
        if [[ "$FILE_DATE_STR" =~ ^[0-9]{8}$ ]]; then
            if [[ "$FILE_DATE_STR" -lt "$CUTOFF_DATE" ]]; then
                echo "[INFO]: deleting $FILENAME"
                rm "$FILE_PATH"
            fi
        fi
    done
else
    echo "[INFO]: Retention skipped. Total backups ($BACKUP_COUNT)."
fi

echo "[SUCCESS]: Backup procedure completed."
exit 0
