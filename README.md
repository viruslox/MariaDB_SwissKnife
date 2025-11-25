# MariaDB SwissKnife

A Bash suite for MariaDB/MySQL database administration, maintenance and security auditing.
Designed for Linux environments, it provides a centralized configuration approach to manage backups, performance tuning, and security checks automagically.

## Dependencies
* `Linux`, `Bash`, `database`...
* `mariadb-client` (or `mysql-client`)
* `mariadb-backup` (or `mysql-backup`)
* `gzip`
* `awk`
* `find`

## Installation & Setup

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/your-username/MariaDB_SwissKnife.git](https://github.com/your-username/MariaDB_SwissKnife.git)
    cd MariaDB_SwissKnife
    chmod +x *.sh
    ```

2.  **Configuration:**
    Run the setup script to detect binaries and store encrypted credentials locally.
    ```bash
    ./setup.sh
    ```

## Usage

### Backup & Retention
Performs logical dumps (`mysqldump`). If database admin credentials are provided, it backs up all databases; 
otherwise it backs up only the selected database. Handles retention based on file dates.

```bash
./Backup_strategy.sh
```
Config: Adjust DB_DUMP_MIN (count) and DB_DUMP_EXPIRE (days) in mariadb.conf.

### Security Audit
Generates a text report in ~/db_audits identifying common security risks (anonymous users, empty passwords, wildcard root access).

```bash
./Security_Audit.sh
```

### Maintenance Routine
Performs a health check:
Index Check: Alerts on tables missing Primary Keys.
Defragmentation: Checks data_free ratio. Runs OPTIMIZE TABLE only if fragmentation > 20% and free space > 100MB.

```bash
./Maintenance.sh
```

### Storage Engine Migration
Mass-converts all tables in the database to a specific engine (default: Aria). Includes a prerun safety dump.

```bash
./Update_Storage_Engine.sh
```

## Automating via Cron
Since mariadb.conf handles authentication, scripts can be scheduled easily via crontab -e:

```bash
# Daily Backup at 02:00 AM
0 2 * * * /path/to/MariaDB_SwissKnife/Backup_strategy.sh >> /var/log/db_backup.log 2>&1

# Weekly Maintenance (Sunday at 04:00 AM)
0 4 * * 0 /path/to/MariaDB_SwissKnife/Maintenance.sh >> /var/log/db_maint.log 2>&1
```

License
This project is licensed under the GNU General Public License v3.0 - see the LICENSE file for details.

Disclaimer
These scripts are provided "as is" without warranty of any kind. Always test on a staging environment before running maintenance operations on production databases.
