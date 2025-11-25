#!/bin/bash

echo "This script performs a read-only security audit on MySQL/MariaDB users/privileges."

CONFIG_FILE="mariadb.conf"

if [[ -f "./$CONFIG_FILE" ]]; then
    source "./$CONFIG_FILE"
else
    echo "[ERR]: Configuration file '$CONFIG_FILE' not found. Run setup.sh first."
    exit 1
fi

if [[ ! -x "$MYSQLCONNECT" ]]; then
    echo "[ERR]: Client binary not found. Run as root: apt install mariadb-client mariadb-backup"
    exit 1
fi

mkdir -p "$AUDIT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M)
REPORT_FILE="${AUDIT_DIR}/Security_Report_${TIMESTAMP}.txt"

## Permission Check
"$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -e "SELECT 1 FROM mysql.user LIMIT 1" > /dev/null 2>&1

if [[ $? -ne 0 ]]; then
    echo "[INFO]: The DB user '$MYSQL_USER' doesn't have admin rights."
    echo "RECOMMENDATION:run the official hardening tool as root:"
    echo "mariadb-secure-installation"
    echo "(or mysql-secure-installation)"
    exit 1
fi

echo "Creating $REPORT_FILE report"

{
    echo "Date: $(date)"
    echo ""

    echo "[INFO]: looking for users with empty passwords"
    RESULT_EMPTY=$("$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -t -e "SELECT User, Host, Plugin FROM mysql.user WHERE (Password = '' OR authentication_string = '') AND Plugin NOT IN ('unix_socket', 'socket')")

    if [[ -z "$RESULT_EMPTY" ]]; then
        echo "STATUS: PASS (No users with empty passwords found)"
    else
        echo "STATUS: FAILED - Found users with empty passwords:"
        echo "$RESULT_EMPTY"
    fi
    echo ""

    echo "[INFO]: looking for anonymous users"
    RESULT_ANON=$("$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -t -e "SELECT User, Host FROM mysql.user WHERE User = ''")

    if [[ -z "$RESULT_ANON" ]]; then
        echo "STATUS: PASS (No anonymous users found)"
    else
        echo "STATUS: FAILED - Found anonymous users:"
        echo "$RESULT_ANON"
    fi
    echo ""

    echo "[INFO] Verify ROOT 'every host' connections (Host = '%')"
    RESULT_ROOT=$("$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -t -e "SELECT User, Host FROM mysql.user WHERE User = 'root' AND Host = '%'")

    if [[ -z "$RESULT_ROOT" ]]; then
        echo "STATUS: PASS (Root cannot connect from 'every host')"
    else
        echo "STATUS: FAILED - Root can setup remote connections from every host:"
        echo "$RESULT_ROOT"
        echo "Recommendation: RENAME USER 'root'@'%' TO 'root'@'localhost'; OR restrict to IP/VLAN"
    fi
    echo ""

} > "$REPORT_FILE"

echo "[INFO]: Audit complete. Check $REPORT_FILE"

exit 0
