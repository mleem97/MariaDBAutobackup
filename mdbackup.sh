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
        # Hier können Sie SSH oder andere Methoden verwenden, um auf das entfernte Gerät zuzugreifen und die Installation durchzuführen
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
