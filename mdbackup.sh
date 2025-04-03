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

# Funktion zur Überprüfung von Abhängigkeiten
check_dependencies() {
    local dependencies=("mysqldump" "gzip" "gunzip")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Error: Required dependency '$dep' is not installed. Please install it first."
            exit 1
        fi
    done
}

# Funktion zur Installation des Skripts
install_script() {
    local script_path="/usr/local/bin/mdbackup"
    if [ ! -f "$script_path" ]; then
        echo "Installing mdbackup script to $script_path..."
        cp "$0" "$script_path"
        chmod +x "$script_path"
        echo "Installation completed."
    else
        echo "mdbackup script is already installed at $script_path."
    fi
}

# Load configuration file if it exists
CONFIG_FILE="/etc/mdbackup.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Default values if not set in configuration
DEFAULT_BACKUP_DIR=${DEFAULT_BACKUP_DIR:-"/var/lib/mysql"}
BACKUP_DIR=${BACKUP_DIR_OVERRIDE:-$DEFAULT_BACKUP_DIR}
LOG_FILE=${LOG_FILE:-"/var/log/mdbackup.log"}

# Funktion zur Bereinigung alter Backups
cleanup_old_backups() {
    echo "Cleaning up backups older than 30 days in $BACKUP_DIR..." | tee -a "$LOG_FILE"
    find "$BACKUP_DIR" -type d -name "backup-*" -mtime +30 -exec rm -rf {} \; | tee -a "$LOG_FILE"
    echo "Old backups cleaned up." | tee -a "$LOG_FILE"
}

# Funktion zur Einrichtung eines Cron-Jobs für tägliche Backups
setup_cron_job() {
    echo "Setting up daily backup cron job..." | tee -a "$LOG_FILE"
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mdbackup backup") | crontab -
    echo "Cron job created for daily backups at 2 AM." | tee -a "$LOG_FILE"
}

# Erweiterte Backup-Funktion mit Logging und Bereinigung
backup() {
    echo "Creating backup..." | tee -a "$LOG_FILE"
    TIMESTAMP=$(date +"%F_%T")
    BACKUP_PATH="$BACKUP_DIR/backup-$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"

    read -p "Do you want to backup all databases? (yes/no): " all_dbs
    if [ "$all_dbs" == "yes" ]; then
        if mysqldump --all-databases > "$BACKUP_PATH/all-databases.sql"; then
            echo "Backup of all databases successful." | tee -a "$LOG_FILE"
        else
            echo "Backup failed!" | tee -a "$LOG_FILE"
            exit 1
        fi
    else
        read -p "Enter the database name to backup: " db_name
        if mysqldump "$db_name" > "$BACKUP_PATH/$db_name.sql"; then
            echo "Backup of database '$db_name' successful." | tee -a "$LOG_FILE"
        else
            echo "Backup failed!" | tee -a "$LOG_FILE"
            exit 1
        fi
    fi

    gzip "$BACKUP_PATH"/*.sql
    chown -R mysql:mysql "$BACKUP_PATH"
    chmod -R 755 "$BACKUP_PATH"
    echo "Backup created at $BACKUP_PATH" | tee -a "$LOG_FILE"

    # Cleanup old backups
    cleanup_old_backups
}

# Erweiterte Restore-Funktion mit Logging
restore() {
    echo "Available backups in $BACKUP_DIR:" | tee -a "$LOG_FILE"
    ls "$BACKUP_DIR" | grep "backup-" || { echo "No backups found." | tee -a "$LOG_FILE"; exit 1; }

    read -p "Enter the backup folder name to restore: " backup_folder
    BACKUP_PATH="$BACKUP_DIR/$backup_folder"

    if [ ! -d "$BACKUP_PATH" ]; then
        echo "Backup folder not found." | tee -a "$LOG_FILE"
        exit 1
    fi

    if [ ! -f "$BACKUP_PATH/all-databases.sql.gz" ] && [ ! -f "$BACKUP_PATH/*.sql.gz" ]; then
        echo "No valid backup files found in the specified directory." | tee -a "$LOG_FILE"
        exit 1
    fi

    echo "Restoring backup from $BACKUP_PATH..." | tee -a "$LOG_FILE"
    for file in "$BACKUP_PATH"/*.sql.gz; do
        if gunzip -c "$file" | mysql; then
            echo "Restored from $file successfully." | tee -a "$LOG_FILE"
        else
            echo "Restore failed for $file!" | tee -a "$LOG_FILE"
            exit 1
        fi
    done

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
    check_dependencies
    install_script

    read -p "Is this being executed on a remote device? (yes/no): " remote_choice
    if [ "$remote_choice" == "yes" ]; then
        read -p "Enter the IP address of the remote device: " remote_ip
        read -p "Enter the username for the remote device: " remote_user
        read -p "Do you want to use SSH key-based authentication? (yes/no): " ssh_key_choice

        if [ "$ssh_key_choice" == "yes" ]; then
            echo "Attempting SSH key-based authentication..."
            scp "$0" "$remote_user@$remote_ip:/usr/local/bin/mdbackup" && \
            ssh "$remote_user@$remote_ip" "chmod +x /usr/local/bin/mdbackup" && \
            echo "Remote installation completed using SSH key-based authentication."
        else
            read -s -p "Enter the password for the remote device: " remote_pass
            echo
            echo "Attempting password-based authentication..."
            sshpass -p "$remote_pass" scp "$0" "$remote_user@$remote_ip:/usr/local/bin/mdbackup" && \
            sshpass -p "$remote_pass" ssh "$remote_user@$remote_ip" "chmod +x /usr/local/bin/mdbackup" && \
            echo "Remote installation completed using password-based authentication."
        fi
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
