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

# Funktion zur Überprüfung und Installation von Abhängigkeiten
check_and_install_dependencies() {
    local dependencies=("mysqldump" "gzip" "gunzip")
    local missing_dependencies=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_dependencies+=("$dep")
        fi
    done

    if [ ${#missing_dependencies[@]} -eq 0 ]; then
        echo "All dependencies are already installed."
        return
    fi

    echo "Dependencies are not fulfilled: ${missing_dependencies[*]}"
    read -p "Do you want to install them now? [Y/n]: " install_choice
    install_choice=${install_choice:-Y}

    if [[ "$install_choice" =~ ^[Yy]$ ]]; then
        for dep in "${missing_dependencies[@]}"; do
            echo "Installing $dep..."
            if command -v apt-get &> /dev/null; then
                sudo apt-get install -y "$dep"
            else
                echo "This script is optimized for Debian-based systems. Please install $dep manually."
                exit 1
            fi
        done
        echo "All missing dependencies have been installed."
    else
        echo "Dependencies were not installed. Exiting."
        exit 1
    fi
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

# Funktion zur Fehlerbehandlung
handle_error() {
    echo "Error: $1" | tee -a "$LOG_FILE"
    exit 1
}

# Funktion zur Validierung der Konfiguration
validate_config() {
    if [ -z "$BACKUP_DIR" ] || [ -z "$LOG_FILE" ]; then
        handle_error "Configuration is invalid. Please check $CONFIG_FILE."
    fi
}

# Funktion zur Verschlüsselung von Backups
encrypt_backup() {
    read -p "Do you want to encrypt the backup? (yes/no): " encrypt_choice
    if [ "$encrypt_choice" == "yes" ]; then
        read -p "Enter the recipient's GPG key ID: " gpg_key
        for file in "$BACKUP_PATH"/*.sql.gz; do
            gpg --encrypt --recipient "$gpg_key" "$file" && rm "$file"
            echo "Backup file $file encrypted." | tee -a "$LOG_FILE"
        done
    fi
}

# Funktion zur Entschlüsselung von Backups
decrypt_backup() {
    read -p "Do you need to decrypt the backup? (yes/no): " decrypt_choice
    if [ "$decrypt_choice" == "yes" ]; then
        for file in "$BACKUP_PATH"/*.sql.gz.gpg; do
            gpg --decrypt "$file" > "${file%.gpg}" && rm "$file"
            echo "Backup file $file decrypted." | tee -a "$LOG_FILE"
        done
    fi
}

# Testmodus aktivieren
TEST_MODE=false

# Wrapper für Befehle im Testmodus
run_command() {
    if [ "$TEST_MODE" == "true" ]; then
        echo "[TEST MODE] $*"
    else
        eval "$@"
    fi
}

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

# Erweiterte Backup-Funktion mit Verschlüsselung
backup() {
    echo "Creating backup..." | tee -a "$LOG_FILE"
    TIMESTAMP=$(date +"%F_%T")
    BACKUP_PATH="$BACKUP_DIR/backup-$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"

    read -p "Do you want to backup all databases? (yes/no): " all_dbs
    if [ "$all_dbs" == "yes" ]; then
        run_command mysqldump --all-databases > "$BACKUP_PATH/all-databases.sql" || handle_error "Backup failed!"
    else
        read -p "Enter the database name to backup: " db_name
        run_command mysqldump "$db_name" > "$BACKUP_PATH/$db_name.sql" || handle_error "Backup failed!"
    fi

    run_command gzip "$BACKUP_PATH"/*.sql
    chown -R mysql:mysql "$BACKUP_PATH"
    chmod -R 755 "$BACKUP_PATH"
    echo "Backup created at $BACKUP_PATH" | tee -a "$LOG_FILE"

    # Optional: Encrypt the backup
    encrypt_backup

    # Cleanup old backups
    cleanup_old_backups
}

# Erweiterte Restore-Funktion mit Entschlüsselung
restore() {
    echo "Available backups in $BACKUP_DIR:" | tee -a "$LOG_FILE"
    ls "$BACKUP_DIR" | grep "backup-" || { echo "No backups found." | tee -a "$LOG_FILE"; exit 1; }

    read -p "Enter the backup folder name to restore: " backup_folder
    BACKUP_PATH="$BACKUP_DIR/$backup_folder"

    if [ ! -d "$BACKUP_PATH" ]; then
        handle_error "Backup folder not found."
    fi

    if [ ! -f "$BACKUP_PATH/all-databases.sql.gz" ] && [ ! -f "$BACKUP_PATH/*.sql.gz.gpg" ]; then
        handle_error "No valid backup files found in the specified directory."
    fi

    # Optional: Decrypt the backup
    decrypt_backup

    echo "Restoring backup from $BACKUP_PATH..." | tee -a "$LOG_FILE"
    for file in "$BACKUP_PATH"/*.sql.gz; do
        run_command gunzip -c "$file" | mysql || handle_error "Restore failed for $file!"
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
    check_and_install_dependencies
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

# Validierung der Konfiguration
validate_config

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
