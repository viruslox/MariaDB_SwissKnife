#!/bin/bash
#### This script updates the engine in all the choosen database tables
#### (Aria if nothing else specified)

unset MYSQL_USER MYSQL_PASSWORD DATABASE MYSQL_HOST MYSQL_PORT MYSQL_ENGINE
MYSQLCONNECT=$(which mysql || which mariadb)
MYSQLANALYZE=$(which mysqlanalyze || which mariadb-analyze)
MYSQLREPAIR=$(which mysqlrepair || which mariadb-repair)
MYSQLOPTIMIZE=$(which mysqloptimize || which mariadb-optimize)
MYSQLDUMP=$(which mysqldump || which mariadb-dump)
echo -n "Please give Your database user name: "
read MYSQL_USER
echo -n "Please give Your database user $MYSQL_USER password: "
read -s MYSQL_PASSWORD
printf "\n"
echo -n "Please give Your database name: "
read DATABASE
echo -n "Please give Your database hostname IF DIFFER BY LOCALHOST: "
read MYSQL_HOST
echo -n "Please give Your database port IF DIFFER BY 3306: "
read MYSQL_PORT
echo -n "Finally specify what engine You wish to set (default: Aria): "
read MYSQL_ENGINE
if [[ $MYSQL_HOST ]]; then
	MYSQL_HOST="--host=$MYSQL_HOST"
else 
	unset MYSQL_HOST
fi
if [[ $MYSQL_PORT ]]; then
        MYSQL_PORT="--port=$MYSQL_PORT"
else
	unset MYSQL_PORT
fi
if [[ ! $MYSQL_ENGINE ]]; then
        MYSQL_ENGINE="Aria"
fi

## check connection
for mycomm in $MYSQLCONNECT $MYSQLANALYZE $MYSQLREPAIR $MYSQLOPTIMIZE $MYSQLDUMP; do
  if [[ ! -x "$mycomm" ]]; then
    echo "Error: $mycomm command not found."
	echo "run as root: apt install mariadb-client mariadb-backup"
    exit 1
  fi
done

## check credentials
"$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" $MYSQL_HOST $MYSQL_PORT -A -D "$DATABASE" -e "select 1" $1 > /dev/null
if [ "$?" -eq 0 ]; then
    echo "Connection to database available"
else
    echo "Connection to database failed, check provided credentials"
	exit 1
fi

## take database dump
filedate=`date +%d%B%Y_%H%m`
"$MYSQLDUMP" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" $MYSQL_HOST $MYSQL_PORT --databases "$DATABASE" > ~/${filedate}_${DATABASE}_dump.sql
echo "Database dump saved in $HOME/${filedate}_${DATABASE}_dump.sql"

## Get table names 
TABLES=()
while IFS= read -r TABLE; do
  TABLES+=("$TABLE")
done < <("$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" $MYSQL_HOST $MYSQL_PORT -A -D "$DATABASE" -N -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA='$DATABASE' AND TABLE_TYPE='BASE TABLE'")

## Alter each table to update the storage engine
for TABLE in "${TABLES[@]}"; do
  echo "Altering Table : $TABLE"
  "$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" $MYSQL_HOST $MYSQL_PORT -D "$DATABASE" -N -e "ALTER TABLE \`$TABLE\` ENGINE=$MYSQL_ENGINE"
	if [ "$?" -ne 0 ]; then
		echo "Error altering table $TABLE: $?"
	fi
done

## Analyze, repair and optimize
$MYSQLANALYZE -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" $MYSQL_HOST $MYSQL_PORT "$DATABASE"
$MYSQLREPAIR -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" $MYSQL_HOST $MYSQL_PORT "$DATABASE"
$MYSQLOPTIMIZE -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" $MYSQL_HOST $MYSQL_PORT "$DATABASE"

echo "Job done"
exit 0
