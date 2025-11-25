#!/bin/bash

echo "This script performs a bulk storage engine migration for a specific database."
echo "Includes pre-run backup and post-execution table optimization."

CONFIG_FILE="mariadb.conf"

if [[ -f "./$CONFIG_FILE" ]]; then
    source "./$CONFIG_FILE"
else
    echo "[ERR]: Configuration file '$CONFIG_FILE' not found. Try re-run setup.sh."
    exit 1
fi

## check binaries
for mycomm in $MYSQLCONNECT $MYSQLANALYZE $MYSQLREPAIR $MYSQLOPTIMIZE $MYSQLDUMP; do
  if [[ ! -x "$mycomm" ]]; then
    echo "Error: $mycomm command not found."
    echo "run as root: apt install mariadb-client mariadb-backup"
    exit 1
  fi
done

## Target Storage Engine (Default: Aria, You can edit this on Your preference)
echo -n "Specify what engine You wish to set (default: Aria): "
read MYSQL_ENGINE
if [[ ! $MYSQL_ENGINE ]]; then
        MYSQL_ENGINE="Aria"
fi

## check credentials
"$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -A -D "$DATABASE" -e "select 1" > /dev/null
if [ "$?" -eq 0 ]; then
    echo "Connection to database available"
else
    echo "Connection to database failed, check provided credentials"
    exit 1
fi

## take database dump
filedate=`date +%d%B%Y_%H%m`
"$MYSQLDUMP" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" --databases "$DATABASE" > ~/${filedate}_${DATABASE}_dump.sql
echo "Database dump saved in $HOME/${filedate}_${DATABASE}_dump.sql"

## Get table names
TABLES=()
while IFS= read -r TABLE; do
  TABLES+=("$TABLE")
done < <("$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -A -D "$DATABASE" -N -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DATABASE' AND TABLE_TYPE='BASE TABLE'")

## Alter each table to update the storage engine
for TABLE in "${TABLES[@]}"; do
  echo "Altering Table : $TABLE"
  "$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -D "$DATABASE" -N -e "ALTER TABLE \`$TABLE\` ENGINE=$MYSQL_ENGINE"
    if [ "$?" -ne 0 ]; then
        echo "Error altering table $TABLE: $?"
    fi
done

## Analyze, repair and optimize
$MYSQLANALYZE -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$DATABASE"
$MYSQLREPAIR -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$DATABASE"
$MYSQLOPTIMIZE -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$DATABASE"

echo "Job done"
exit 0
