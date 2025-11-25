#!/bin/bash

echo "This script identifies performance risks (Tables without Primary Keys) and performs conditional optimization based on fragmentation heuristics."

CONFIG_FILE="mariadb.conf"

if [[ -f "./$CONFIG_FILE" ]]; then
    source "./$CONFIG_FILE"
else
    echo "[ERR]: Configuration file '$CONFIG_FILE' not found. Run setup.sh first."
    exit 1
fi

# Thresholds for Defragmentation
# FRAG_RATIO: 0.2 means 20% fragmentation
# MIN_DATA_FREE: 104857600 bytes means 100MB. We ignore small holes.
FRAG_RATIO=0.2
MIN_DATA_FREE=104857600

if [[ ! -x "$MYSQLCONNECT" ]]; then
    echo "[ERR]: Client binary not found. Run as root: apt install mariadb-client mariadb-backup"
    exit 1
fi


echo "[INFO]: Index health check - missing primary keys"
# The Logic: Find tables in the target schema that are NOT present in the table_constraints list associated with a 'PRIMARY KEY' constraint type.

MISSING_PK_TABLES=()
while IFS= read -r TABLE; do
    MISSING_PK_TABLES+=("$TABLE")
done < <("$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -N -e "
    SELECT t.table_name
    FROM information_schema.tables t
    LEFT JOIN information_schema.table_constraints c
    ON t.table_schema = c.table_schema
    AND t.table_name = c.table_name
    AND c.constraint_type = 'PRIMARY KEY'
    WHERE t.table_schema = '$DATABASE'
    AND t.table_type = 'BASE TABLE'
    AND c.constraint_name IS NULL;")

if [[ ${#MISSING_PK_TABLES[@]} -eq 0 ]]; then
    echo "[OK]: All tables have Primary Keys."
else
    echo "[WARN]: The following tables LACK a Primary Key:"
    for TBL in "${MISSING_PK_TABLES[@]}"; do
        echo "  - $TBL"
    done
    echo "Consider adding an AUTO_INCREMENT Primary Key to these tables."
fi

echo "[INFO]: Fragmentation analysis & optimization"
# The Logic: Calculate fragmentation ratio only for tables with significant empty space.
# Data Free > $((MIN_DATA_FREE / 1024 / 1024))MB AND Fragmentation > $(awk "BEGIN {print $FRAG_RATIO*100}")%"

FRAGMENTED_TABLES=()
while IFS=$'\t' read -r TBL D_LEN D_FREE; do
    FRAGMENTED_TABLES+=("$TBL")
done < <("$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -N -e "
    SELECT table_name, data_length, data_free
    FROM information_schema.tables
    WHERE table_schema = '$DATABASE'
    AND table_type = 'BASE TABLE'
    AND data_length > 0
    AND data_free > $MIN_DATA_FREE
    AND (data_free / data_length) > $FRAG_RATIO;")

if [[ ${#FRAGMENTED_TABLES[@]} -eq 0 ]]; then
    echo "[OK]: No tables exceed fragmentation thresholds. No need to run optimization."
else
    echo "[INFO]: Optimizing ${#FRAGMENTED_TABLES[@]} fragmented tables"

    for TBL in "${FRAGMENTED_TABLES[@]}"; do
        echo "Optimizing table '$TBL'"
        "$MYSQLCONNECT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -P "$MYSQL_PORT" -D "$DATABASE" -e "OPTIMIZE TABLE \`$TBL\`" > /dev/null 2>&1

        if [[ $? -eq 0 ]]; then
            echo "DONE"
        else
            echo "FAILED"
        fi
    done
fi

echo ""
echo "Maintenance complete."

exit 0
