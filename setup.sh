#!/bin/bash

CONFIG_FILE="mariadb.conf"

echo "This script creates (and re-creates) the configuration file for Your DB service"
echo "If You already have a configuration file, just press ctrl-c before replay to the new questions."

# Check and find database client binaries
MYSQLCONNECT=$(which mysql || which mariadb)
if [[ ! -x "$MYSQLCONNECT" ]]; then
    echo "[ERR]: mysql/mariadb client binaries not found on Your enviroment. Quit"
    exit 1
fi
MYSQLDUMP=$(which mysqldump || which mariadb-dump)
MYSQLANALYZE=$(which mysqlanalyze || which mariadb-analyze)
MYSQLREPAIR=$(which mysqlrepair || which mariadb-repair)
MYSQLOPTIMIZE=$(which mysqloptimize || which mariadb-optimize)

getthecredentials() {
    echo -n "Database User: "
    read MYSQL_USER
    echo -n "Database Password per $MYSQL_USER: "
    read -s MYSQL_PASSWORD
    printf "\n"
    echo -n "Database Name: "
    read DATABASE
    echo -n "Database Host (press enter for localhost): "
    read MYSQL_HOST
    echo -n "Database Port (press enter for 3306): "
    read MYSQL_PORT
    MYSQL_HOST=${MYSQL_HOST:-"localhost"}
    MYSQL_PORT=${MYSQL_PORT:-"3306"}
}

savethedata() {
    cat > "$CONFIG_FILE" <<EOF
# MariaDB SwissKnife Configuration
# Updated on $(date)

MYSQL_USER="$MYSQL_USER"
MYSQL_PASSWORD="$MYSQL_PASSWORD"
DATABASE="$DATABASE"
MYSQL_HOST="$MYSQL_HOST"
MYSQL_PORT="$MYSQL_PORT"

# Binaries Paths
MYSQLCONNECT="$MYSQLCONNECT"
MYSQLDUMP="$MYSQLDUMP"
MYSQLANALYZE="$MYSQLANALYZE"
MYSQLREPAIR="$MYSQLREPAIR"
MYSQLOPTIMIZE="$MYSQLOPTIMIZE"

BACKUP_DIR="${HOME}/db_backups"
# How many backups keep in folder
DB_DUMP_MIN=5
# How many days retain a backup
DB_DUMP_EXPIRE=30

AUDIT_DIR="${HOME}/db_audits"
EOF

    chmod 600 "$CONFIG_FILE"
    echo "[INFO]: Connection details and credentials saved in: $CONFIG_FILE"
}


# Main
while true; do
    getthecredentials
    "$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "select 1" > /dev/null 2>&1
    if [ "$?" -eq 0 ]; then
        echo "[INFO]: Credentials verified: Connected."
        savethedata
        break
    else
        echo "[WARN]: Connection failed. Please check your password or host."
        echo -n "Do you want to retry? [Y/n]: "
        read REPLY
        if [[ "$REPLY" =~ ^[Nn]$ ]]; then
            echo "[INFO]: Setup aborted by user."
            exit 1
        fi
    fi
done

exit 0
