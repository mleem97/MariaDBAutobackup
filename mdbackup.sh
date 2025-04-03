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

# Funktion zur Erstellung eines Backups
backup() {
    echo "Creating backup..."
    TIMESTAMP=$(date +"%F")
    BACKUP_DIR="/var/lib/mysql/backup-$TIMESTAMP"
    mkdir -p "$BACKUP_DIR"
    mysqldump --all-databases > "$BACKUP_DIR/all-databases.sql"
    chown -R mysql:mysql "$BACKUP_DIR"
    chmod -R 755 "$BACKUP_DIR"
    echo "Backup created at $BACKUP_DIR"
}

# Funktion zur Wiederherstellung eines Backups
restore() {
    if [ -z "$1" ]; then
        echo "Please provide the path to the backup directory."
        exit 1
    fi

    BACKUP_DIR=$1
    if [ ! -f "$BACKUP_DIR/all-databases.sql" ]; then
        echo "Backup file not found in the specified directory."
        exit 1
    fi

    echo "Restoring backup from $BACKUP_DIR..."
    mysql < "$BACKUP_DIR/all-databases.sql"
    chown -R mysql:mysql /var/lib/mysql
    chmod -R 755 /var/lib/mysql
    echo "Backup restored from $BACKUP_DIR"
}

# Hauptprogramm
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
