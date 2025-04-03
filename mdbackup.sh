#!/bin/bash

# Funktion zur Anzeige der Hilfe
show_help() {
    echo "Usage: mdbackup [command]"
    echo ""
    echo "Commands:"
    echo "  backup      Create a backup of MariaDB database"
    echo "  restore     Restore a MariaDB database from a backup"
    echo "  help        Display this help message"
}

# Funktion zur Überprüfung, ob MariaDB oder MySQL installiert ist
check_mariadb_mysql_installed() {
    if command -v mysql &> /dev/null; then
        echo "MySQL/MariaDB is installed."
    else
        echo "MySQL/MariaDB is not installed. Please install it first."
        exit 1
    fi
}

# Default backup directory (can be overridden by environment variable)
DEFAULT_BACKUP_DIR="/var/lib/mysql"
BACKUP_DIR=${BACKUP_DIR_OVERRIDE:-$DEFAULT_BACKUP_DIR}

# Log file for operations
LOG_FILE="/var/log/mdbackup.log"

# Funktion zur Erstellung eines Backups
backup() {
    echo "Creating backup..."
    TIMESTAMP=$(date +"%F_%T")
    BACKUP_PATH="$BACKUP_DIR/backup-$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"
    mysqldump --all-databases > "$BACKUP_PATH/all-databases.sql"
    gzip "$BACKUP_PATH/all-databases.sql"
    chown -R mysql:mysql "$BACKUP_PATH"
    chmod -R 755 "$BACKUP_PATH"
    echo "Backup created at $BACKUP_PATH" | tee -a "$LOG_FILE"
}

# Funktion zur Wiederherstellung eines Backups
restore() {
    if [ -z "$1" ]; then
        echo "Please provide the path to the backup directory."
        exit 1
    fi

    BACKUP_PATH=$1
    if [ ! -f "$BACKUP_PATH/all-databases.sql.gz" ]; then
        echo "Compressed backup file not found in the specified directory."
        exit 1
    fi

    echo "Restoring backup from $BACKUP_PATH..."
    gunzip -c "$BACKUP_PATH/all-databases.sql.gz" | mysql
    chown -R mysql:mysql /var/lib/mysql
    chmod -R 755 /var/lib/mysql
    echo "Backup restored from $BACKUP_PATH" | tee -a "$LOG_FILE"
}

# Funktion zur Installation und Konfiguration
install() {
    read -p "Do you want to install the mdbackup application? (yes/no): " install_choice
    if [ "$install_choice" != "yes" ]; then
        echo "Installation aborted."
        exit 0
    fi

    check_mariadb_mysql_installed

    read -p "Is this being executed on a remote device? (yes/no): " remote_choice
    if [ "$remote_choice" == "yes" ]; then
        read -p "Enter the IP address of the remote device: " remote_ip
        read -p "Enter the username for the remote device: " remote_user
        read -s -p "Enter the password for the remote device: " remote_pass
        echo
        # Implementierung Verbindung zum SSH des DB servers oder so.
        echo "Remote installation not implemented in this script."
    else
        echo "Local installation completed."
    fi
}

# Hauptprogramm
if [ ! -f /usr/local/bin/mdbackup ]; then
    install
fi

case "$1" in
    backup)
        backup
        ;;
    restore)
        restore "$2"
        ;;
    help|*)
        show_help
        ;;
esac
