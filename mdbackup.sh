#!/bin/bash

# Note: Ensure the script has executable permissions before running:
#       chmod +x mdbackup.sh
#       ./mdbackup.sh [command]

VERSION="1.1.5" # Aktualisierte Skriptversion
REMOTE_VERSION_URL="https://raw.githubusercontent.com/mleem97/MariaDBAutobackup/refs/heads/main/version.txt"

# Konfigurationsdatei
CONFIG_FILE="/etc/mdbackup.conf"
LOCAL_CONFIG_FILE="$(dirname "$0")/mdbackup.conf"

# Funktion zum Laden der Konfiguration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    elif [ -f "$LOCAL_CONFIG_FILE" ]; then
        source "$LOCAL_CONFIG_FILE"
    else
        echo "Warning: Configuration file not found. Using default values."
    fi
    # Setze Standardwerte, falls in der Konfiguration nicht vorhanden
    DATABASE_HOST="${DATABASE_HOST:-localhost}"
    DATABASE_USER="${DATABASE_USER:-root}"
    BACKUP_DIR="${BACKUP_DIR:-/var/lib/mysql-backups}"
    LOG_FILE="${LOG_FILE:-/var/log/mdbackup.log}"
    BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
    GZIP_COMPRESSION_LEVEL="${GZIP_COMPRESSION_LEVEL:-6}"
    ENCRYPT_BACKUPS="${ENCRYPT_BACKUPS:-no}"
    GPG_KEY_ID="${GPG_KEY_ID:-}"
    BACKUP_TIME="${BACKUP_TIME:-02:00}"
}

# Konfiguration laden
load_config

# Funktion zur Anzeige der Hilfe
show_help() {
    echo "Usage: mdbackup [command]"
    echo ""
    echo "Commands:"
    echo "  backup          Create a backup of MariaDB database"
    echo "  restore         Restore a MariaDB database from a backup"
    echo "  configure       Configure mdbackup settings"
    echo "  update          Update the mdbackup script to the latest version"
    echo "  version         Show the current version of mdbackup"
    echo "  check-updates   Check for updates to the mdbackup script"
    echo "  install         Install mdbackup and set up service"
    echo "  uninstall       Uninstall mdbackup and remove service"
    echo "  help            Display this help message"
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
    if [ "$ENCRYPT_BACKUPS" == "yes" ]; then
        dependencies+=("gpg")
    fi
    if [ "$1" == "install" ]; then
        dependencies+=("systemctl")
    fi
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
    if [ "$ENCRYPT_BACKUPS" == "yes" ]; then
        dependencies+=("gpg")
    fi
    local missing_dependencies=()
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_dependencies+=("$dep")
        fi
    done

    if [ ${#missing_dependencies[@]} -eq 0 ]; then
        echo "All necessary dependencies are already installed."
        return
    fi

    echo "The following dependencies are missing: ${missing_dependencies[*]}"
    read -p "Do you want to install them now? [Y/n]: " install_choice
    install_choice=${install_choice:-Y}

    if [[ "$install_choice" =~ ^[Yy] ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            for dep in "${missing_dependencies[@]}"; do
                echo "Installing $dep..."
                sudo apt-get install -y "$dep"
            done
            echo "All missing dependencies have been installed."
        else
            echo "This script is optimized for Debian-based systems using apt-get. Please install the missing dependencies manually."
            exit 1
        fi
    else
        echo "Dependencies were not installed. Exiting."
        exit 1
    fi
}

# Funktion zur Installation des Skripts und der Systemd-Dateien
install_script() {
    local script_path="/usr/local/bin/mdbackup"
    local service_file="/etc/systemd/system/mdbackup.service"
    local timer_file="/etc/systemd/system/mdbackup.timer"

    echo "Installing mdbackup script to $script_path..."
    sudo cp "$0" "$script_path"
    sudo chmod +x "$script_path"

    echo "Installing systemd service file to $service_file..."
    echo "[Unit]" | sudo tee "$service_file"
    echo "Description=MariaDB/MySQL Automatic Backup Service" | sudo tee -a "$service_file"
    echo "After=network.target mysql.service mariadb.service" | sudo tee -a "$service_file"
    echo "Requires=mysql.service mariadb.service" | sudo tee -a "$service_file"
    echo "" | sudo tee -a "$service_file"
    echo "[Service]" | sudo tee -a "$service_file"
    echo "User=root" | sudo tee -a "$service_file"
    echo "Group=root" | sudo tee -a "$service_file"
    echo "Type=oneshot" | sudo tee -a "$service_file"
    echo "EnvironmentFile=$CONFIG_FILE" | sudo tee -a "$service_file"
    echo "ExecStart=$script_path backup" | sudo tee -a "$service_file"
    echo "StandardOutput=append:%LOG_FILE%" | sudo tee -a "$service_file"
    echo "StandardError=append:%LOG_FILE%" | sudo tee -a "$service_file"

    echo "Installing systemd timer file to $timer_file..."
    echo "[Unit]" | sudo tee "$timer_file"
    echo "Description=Daily MariaDB/MySQL Backup Timer" | sudo tee -a "$timer_file"
    echo "After=mdbackup.service" | sudo tee -a "$timer_file"
    echo "" | sudo tee -a "$timer_file"
    echo "[Timer]" | sudo tee -a "$timer_file"
    echo "Unit=mdbackup.service" | sudo tee -a "$timer_file"
    echo "OnCalendar=*-*-*:%BACKUP_TIME%" | sudo tee -a "$timer_file"
    echo "Persistent=true" | sudo tee -a "$timer_file"
    echo "" | sudo tee -a "$timer_file"
    echo "[Install]" | sudo tee -a "$timer_file"
    echo "WantedBy=timers.target" | sudo tee -a "$timer_file"

    echo "Enabling and starting the mdbackup timer..."
    sudo systemctl daemon-reload
    sudo systemctl enable mdbackup.timer
    sudo systemctl start mdbackup.timer

    echo "Installation completed. The daily backup will run at the time specified in $CONFIG_FILE."
}

# Funktion zur Deinstallation des Skripts und der Systemd-Dateien
uninstall_script() {
    local script_path="/usr/local/bin/mdbackup"
    local service_file="/etc/systemd/system/mdbackup.service"
    local timer_file="/etc/systemd/system/mdbackup.timer"
    read -p "Are you sure you want to uninstall mdbackup? This will stop the timer and remove the script and service files. [Y/n]: " uninstall_choice
    uninstall_choice=${uninstall_choice:-N}

    if [[ "$uninstall_choice" =~ ^[Yy] ]]; then
        echo "Stopping and disabling the mdbackup timer..."
        sudo systemctl stop mdbackup.timer
        sudo systemctl disable mdbackup.timer

        echo "Removing systemd service file $service_file..."
        sudo rm -f "$service_file"

        echo "Removing systemd timer file $timer_file..."
        sudo rm -f "$timer_file"

        echo "Removing script $script_path..."
        sudo rm -f "$script_path"

        sudo systemctl daemon-reload
        echo "Uninstallation completed."
    else
        echo "Uninstallation aborted."
    fi
}

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
    if [ "$ENCRYPT_BACKUPS" == "yes" ] && [ -z "$GPG_KEY_ID" ]; then
        echo "Warning: Encryption is enabled but GPG key ID is not set in the configuration." | tee -a "$LOG_FILE"
    fi
}

# Funktion zur Verschlüsselung von Backups
encrypt_backup() {
    if [ "$ENCRYPT_BACKUPS" == "yes" ] && [ -n "$GPG_KEY_ID" ]; then
        echo "Encrypting backups with GPG key ID: $GPG_KEY_ID..." | tee -a "$LOG_FILE"
        for file in "$BACKUP_PATH"/*.sql.gz; do
            gpg --encrypt --recipient "$GPG_KEY_ID" "$file" && rm "$file"
            echo "Backup file $file encrypted." | tee -a "$LOG_FILE"
        done
    elif [ "$ENCRYPT_BACKUPS" == "yes" ] && [ -z "$GPG_KEY_ID" ]; then
        echo "Warning: Encryption is enabled but GPG key ID is not set. Skipping encryption." | tee -a "$LOG_FILE"
    fi
}

# Funktion zur Entschlüsselung von Backups
decrypt_backup() {
    read -p "Do you need to decrypt the backup? (yes/no): " decrypt_choice
    if [ "$decrypt_choice" == "yes" ]; then
        echo "Decrypting backup files..." | tee -a "$LOG_FILE"
        for file in "$BACKUP_PATH"/*.sql.gz.gpg; do
            gpg --decrypt --output "${file%.gpg}" "$file" && rm "$file"
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
    echo "Cleaning up backups older than $BACKUP_RETENTION_DAYS days in $BACKUP_DIR..." | tee -a "$LOG_FILE"
    find "$BACKUP_DIR" -type d -name "backup-*" -mtime +"$BACKUP_RETENTION_DAYS" -exec rm -rf {} \; | tee -a "$LOG_FILE"
    echo "Old backups cleaned up." | tee -a "$LOG_FILE"
}

# Funktion zur Durchführung von Backups (vollständig, differenziell, inkrementell)
perform_backup() {
    local backup_type=$1
    local last_full_backup="$(find "$BACKUP_DIR" -type d -name "backup-full-*" | sort | tail -n 1)"
    local last_backup="$(find "$BACKUP_DIR" -type d -name "backup-*" | sort | tail -n 1)"

    TIMESTAMP=$(date +"%F_%T")
    BACKUP_PATH="$BACKUP_DIR/backup-$backup_type-$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"

    case $backup_type in
        full)
            echo "Performing full backup..." | tee -a "$LOG_FILE"
            mysqldump -h "$DATABASE_HOST" -u "$DATABASE_USER" --all-databases > "$BACKUP_PATH/all-databases.sql" || handle_error "Full backup failed!"
            ;;
        differential)
            if [ -z "$last_full_backup" ]; then
                handle_error "No previous full backup found. Please perform a full backup first."
            fi
            echo "Performing differential backup since $last_full_backup..." | tee -a "$LOG_FILE"
            mysqldump -h "$DATABASE_HOST" -u "$DATABASE_USER" --all-databases --flush-logs --master-data=2 --single-transaction --incremental-base-dir="$last_full_backup" > "$BACKUP_PATH/differential.sql" || handle_error "Differential backup failed!"
            ;;
        incremental)
            if [ -z "$last_backup" ]; then
                handle_error "No previous backup found. Please perform a full or differential backup first."
            fi
            echo "Performing incremental backup since $last_backup..." | tee -a "$LOG_FILE"
            mysqldump -h "$DATABASE_HOST" -u "$DATABASE_USER" --all-databases --flush-logs --master-data=2 --single-transaction --incremental-base-dir="$last_backup" > "$BACKUP_PATH/incremental.sql" || handle_error "Incremental backup failed!"
            ;;
        *)
            handle_error "Invalid backup type specified. Use 'full', 'differential', or 'incremental'."
            ;;
    esac

    gzip -"$GZIP_COMPRESSION_LEVEL" "$BACKUP_PATH"/*.sql
    chown -R mysql:mysql "$BACKUP_PATH"
    chmod -R 755 "$BACKUP_PATH"
    echo "Backup completed: $BACKUP_PATH" | tee -a "$LOG_FILE"
}

# Funktion zur Durchführung von Backups bestimmter Tabellen
backup_specific_tables() {
    read -p "Enter the database name: " database_name
    read -p "Enter the table names (comma-separated): " table_names

    TIMESTAMP=$(date +"%F_%T")
    BACKUP_PATH="$BACKUP_DIR/backup-tables-$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"

    echo "Backing up tables [$table_names] from database [$database_name]..." | tee -a "$LOG_FILE"
    mysqldump -h "$DATABASE_HOST" -u "$DATABASE_USER" "$database_name" $table_names > "$BACKUP_PATH/tables.sql" || handle_error "Backup of specific tables failed!"

    gzip -"$GZIP_COMPRESSION_LEVEL" "$BACKUP_PATH/tables.sql"
    chown -R mysql:mysql "$BACKUP_PATH"
    chmod -R 755 "$BACKUP_PATH"
    echo "Backup of specific tables completed: $BACKUP_PATH" | tee -a "$LOG_FILE"
}

# Funktion zur Ausführung von Pre- und Post-Backup-Hooks
run_hooks() {
    local hook_type=$1
    local hook_script="${hook_type}_backup_hook.sh"

    if [ -f "$hook_script" ]; then
        echo "Running $hook_type-backup hook..." | tee -a "$LOG_FILE"
        bash "$hook_script" || handle_error "$hook_type-backup hook failed!"
    else
        echo "No $hook_type-backup hook found. Skipping." | tee -a "$LOG_FILE"
    fi
}

# Erweiterung der Backup-Funktion zur Unterstützung von Tabellen-Backups und Hooks
backup() {
    echo "Select backup type:"
    echo "1) Full"
    echo "2) Differential"
    echo "3) Incremental"
    echo "4) Specific Tables"
    read -p "Enter your choice (1/2/3/4): " choice

    run_hooks pre

    case $choice in
        1)
            perform_backup full
            ;;
        2)
            perform_backup differential
            ;;
        3)
            perform_backup incremental
            ;;
        4)
            backup_specific_tables
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    run_hooks post
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

    if [ ! -f "$BACKUP_PATH/all-databases.sql.gz" ] && [ ! -f "$BACKUP_PATH/*.sql.gz.gpg" ] && [ ! -f "$BACKUP_PATH/*.sql.gz" ]; then
        handle_error "No valid backup files found in the specified directory."
    fi

    # Optional: Decrypt the backup
    decrypt_backup

    echo "Restoring backup from $BACKUP_PATH..." | tee -a "$LOG_FILE"
    for file in "$BACKUP_PATH"/*.sql.gz; do
        run_command gunzip -c "$file" | mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" "$DATABASE_PASSWORD" || handle_error "Restore failed for $file!"
    done
    for file in "$BACKUP_PATH"/*.sql; do
        run_command mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" "$DATABASE_PASSWORD" < "$file" || handle_error "Restore failed for $file!"
    done

    chown -R mysql:mysql /var/lib/mysql
    chmod -R 755 /var/lib/mysql
    echo "Backup restored from $BACKUP_PATH" | tee -a "$LOG_FILE"
}

# Funktion zur Installation
install() {
    read -p "Do you want to install the mdbackup application? [Y/n]: " install_choice
    install_choice=${install_choice:-Y}

    if [[ "$install_choice" =~ ^[Yy] ]]; then
        check_dependencies install
        install_script
    else
        echo "Installation aborted."
    fi
}

# Funktion zur Fortschrittsanzeige
show_progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    printf "\rProgress: [%-50s] %d%%" $(printf "#%.0s" $(seq 1 $((percent / 2)))) $percent
}

# Automatische Update-Funktion
check_for_updates() {
    echo "Checking for updates..." | tee -a "$LOG_FILE"
    local remote_version=$(curl -s "$REMOTE_VERSION_URL")
    if [ "$remote_version" != "$VERSION" ]; then
        echo "Update available: $remote_version. Updating..." | tee -a "$LOG_FILE"
        curl -o "$0" "$REMOTE_VERSION_URL" && chmod +x "$0"
        echo "Update completed. Please restart the script." | tee -a "$LOG_FILE"
        exit 0
    else
        echo "No updates available." | tee -a "$LOG_FILE"
    fi
}

# Konfigurationsprüfung
validate_config_file() {
    echo "Validating configuration file..." | tee -a "$LOG_FILE"
    if [ ! -f "$CONFIG_FILE" ] && [ ! -f "$LOCAL_CONFIG_FILE" ]; then
        handle_error "Configuration file not found."
    fi

    source "$CONFIG_FILE" 2>/dev/null || source "$LOCAL_CONFIG_FILE" 2>/dev/null

    if [ -z "$DATABASE_HOST" ] || [ -z "$DATABASE_USER" ] || [ -z "$BACKUP_DIR" ]; then
        handle_error "Configuration file is missing required fields."
    fi
    echo "Configuration file is valid." | tee -a "$LOG_FILE"
}

# Dokumentation
#
# Dieses Skript dient zur automatischen Sicherung und Wiederherstellung von MariaDB/MySQL-Datenbanken.
#
# Konfigurationsoptionen:
# - DATABASE_HOST: Hostname der Datenbank (Standard: localhost)
# - DATABASE_USER: Benutzername für die Datenbank (Standard: root)
# - BACKUP_DIR: Verzeichnis für Backups (Standard: /var/lib/mysql-backups)
# - LOG_FILE: Pfad zur Logdatei (Standard: /var/log/mdbackup.log)
# - BACKUP_RETENTION_DAYS: Anzahl der Tage, nach denen alte Backups gelöscht werden (Standard: 7)
# - GZIP_COMPRESSION_LEVEL: Kompressionsstufe für gzip (Standard: 6)
# - ENCRYPT_BACKUPS: Ob Backups verschlüsselt werden sollen (yes/no, Standard: no)
# - GPG_KEY_ID: GPG-Schlüssel-ID für die Verschlüsselung (falls ENCRYPT_BACKUPS=yes)
# - BACKUP_TIME: Zeit für geplante Backups (Standard: 02:00)
#
# Befehle:
# - backup: Erstellt ein Backup der Datenbank.
# - restore: Stellt eine Datenbank aus einem Backup wieder her.
# - configure: Konfiguriert die Einstellungen des Skripts.
# - update: Aktualisiert das Skript auf die neueste Version.
# - version: Zeigt die aktuelle Version des Skripts an.
# - check-updates: Überprüft auf Updates für das Skript.
# - install: Installiert das Skript und richtet den Service ein.
# - uninstall: Deinstalliert das Skript und entfernt den Service.
# - help: Zeigt diese Hilfe an.