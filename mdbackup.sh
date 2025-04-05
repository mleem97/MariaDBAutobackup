#!/bin/bash

# Note: Ensure the script has executable permissions before running:
#       chmod +x mdbackup.sh
#       ./mdbackup.sh [command]

VERSION="1.1.7" # Aktualisierte Skriptversion
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
    COMPRESSION_ALGORITHM="${COMPRESSION_ALGORITHM:-gzip}"
    COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-6}"
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
    echo "  verify          Verify backup integrity"
    echo "  configure-compression Configure compression settings"
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

# Funktion zur Berechnung und Speicherung von Prüfsummen für Backup-Dateien
calculate_checksum() {
    local backup_dir=$1
    echo "Calculating checksums for backup files in $backup_dir..." | tee -a "$LOG_FILE"
    find "$backup_dir" -type f -name "*.sql*" | while read -r file; do
        if command -v sha256sum &> /dev/null; then
            sha256sum "$file" >> "$backup_dir/checksums.sha256"
        elif command -v shasum &> /dev/null; then
            shasum -a 256 "$file" >> "$backup_dir/checksums.sha256"
        else
            echo "Warning: No checksum tool found. Skipping checksum calculation." | tee -a "$LOG_FILE"
            return
        fi
    done
    echo "Checksums calculated and stored in $backup_dir/checksums.sha256" | tee -a "$LOG_FILE"
}

# Funktion zur Überprüfung der Backup-Integrität
verify_backup_integrity() {
    echo "Available backups in $BACKUP_DIR:" | tee -a "$LOG_FILE"
    ls "$BACKUP_DIR" | grep "backup-" || { echo "No backups found." | tee -a "$LOG_FILE"; exit 1; }

    read -p "Enter the backup folder name to verify: " backup_folder
    BACKUP_PATH="$BACKUP_DIR/$backup_folder"

    if [ ! -d "$BACKUP_PATH" ]; then
        handle_error "Backup folder not found."
    fi

    if [ ! -f "$BACKUP_PATH/checksums.sha256" ]; then
        handle_error "No checksums file found for this backup."
    fi

    echo "Verifying backup integrity for $BACKUP_PATH..." | tee -a "$LOG_FILE"
    if command -v sha256sum &> /dev/null; then
        cd "$BACKUP_PATH" && sha256sum -c checksums.sha256
    elif command -v shasum &> /dev/null; then
        cd "$BACKUP_PATH" && shasum -a 256 -c checksums.sha256
    else
        handle_error "No checksum verification tool found."
    fi
    if [ $? -eq 0 ]; then
        echo "Backup integrity verified successfully!" | tee -a "$LOG_FILE"
    else
        handle_error "Backup integrity check failed. Some files may be corrupted."
    fi
}

# Funktion zur Komprimierung von Backup-Dateien mit verschiedenen Algorithmen
compress_backup() {
    local backup_dir=$1
    local compression_algorithm=$2
    local compression_level=$3
    echo "Compressing backup files in $backup_dir using $compression_algorithm level $compression_level..." | tee -a "$LOG_FILE"
    find "$backup_dir" -type f -name "*.sql" | while read -r file; do
        case $compression_algorithm in
            gzip)
                gzip -"$compression_level" "$file"
                ;;
            bzip2)
                bzip2 -"$compression_level" "$file"
                ;;
            xz)
                xz -"$compression_level" "$file"
                ;;
            *)
                handle_error "Unknown compression algorithm: $compression_algorithm"
                ;;
        esac
        echo "Compressed $file using $compression_algorithm" | tee -a "$LOG_FILE"
    done
    echo "All backup files compressed successfully!" | tee -a "$LOG_FILE"
}

# Erweiterung der Konfigurationsfunktion für Komprimierungseinstellungen
configure_compression() {
    echo "Configure compression settings:"
    echo "1) gzip (fastest, moderate compression)"
    echo "2) bzip2 (slower, better compression)"
    echo "3) xz (slowest, best compression)"
    read -p "Select compression algorithm [1-3] (default: 1): " compression_choice
    case ${compression_choice:-1} in
        1)
            COMPRESSION_ALGORITHM="gzip"
            ;;
        2)
            COMPRESSION_ALGORITHM="bzip2"
            ;;
        3)
            COMPRESSION_ALGORITHM="xz"
            ;;
        *)
            echo "Invalid choice. Using default (gzip)."
            COMPRESSION_ALGORITHM="gzip"
            ;;
    esac
    read -p "Select compression level [1-9] (default: 6, higher = better compression but slower): " compression_level
    COMPRESSION_LEVEL=${compression_level:-6}
    # Update config file
    if grep -q "COMPRESSION_ALGORITHM" "$CONFIG_FILE"; then
        sed -i "s/COMPRESSION_ALGORITHM=.*/COMPRESSION_ALGORITHM=\"$COMPRESSION_ALGORITHM\"/" "$CONFIG_FILE"
    else
        echo "COMPRESSION_ALGORITHM=\"$COMPRESSION_ALGORITHM\"" >> "$CONFIG_FILE"
    fi
    if grep -q "COMPRESSION_LEVEL" "$CONFIG_FILE"; then
        sed -i "s/COMPRESSION_LEVEL=.*/COMPRESSION_LEVEL=\"$COMPRESSION_LEVEL\"/" "$CONFIG_FILE"
    else
        echo "COMPRESSION_LEVEL=\"$COMPRESSION_LEVEL\"" >> "$CONFIG_FILE"
    fi
    echo "Compression settings updated in configuration file."
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

    # Komprimiere die Backup-Dateien mit dem konfigurierten Algorithmus
    compress_backup "$BACKUP_PATH" "$COMPRESSION_ALGORITHM" "$COMPRESSION_LEVEL"
    # Berechne und speichere Prüfsummen für die Backup-Dateien
    calculate_checksum "$BACKUP_PATH"
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

# Funktion zur Übertragung von Backups auf einen entfernten Speicherort
transfer_backup_to_remote() {
    if [ -z "$REMOTE_BACKUP_ENABLED" ] || [ "$REMOTE_BACKUP_ENABLED" != "yes" ]; then
        echo "Remote backup is disabled. Skipping transfer." | tee -a "$LOG_FILE"
        return
    fi

    echo "Transferring backup to remote storage..." | tee -a "$LOG_FILE"

    if [ -n "$REMOTE_NFS_MOUNT" ]; then
        echo "Using NFS mount: $REMOTE_NFS_MOUNT" | tee -a "$LOG_FILE"
        if ! mountpoint -q "$REMOTE_NFS_MOUNT"; then
            mount "$REMOTE_NFS_MOUNT" || handle_error "Failed to mount NFS share."
        fi
        cp -r "$BACKUP_PATH" "$REMOTE_NFS_MOUNT" || handle_error "Failed to copy backup to NFS share."
    elif [ -n "$REMOTE_RSYNC_TARGET" ]; then
        echo "Using rsync target: $REMOTE_RSYNC_TARGET" | tee -a "$LOG_FILE"
        rsync -avz "$BACKUP_PATH" "$REMOTE_RSYNC_TARGET" || handle_error "Failed to transfer backup using rsync."
    elif [ -n "$REMOTE_CLOUD_CLI" ] && [ -n "$REMOTE_CLOUD_BUCKET" ]; then
        echo "Using cloud storage: $REMOTE_CLOUD_BUCKET" | tee -a "$LOG_FILE"
        "$REMOTE_CLOUD_CLI" cp "$BACKUP_PATH" "$REMOTE_CLOUD_BUCKET" --recursive || handle_error "Failed to transfer backup to cloud storage."
    else
        handle_error "No valid remote backup configuration found."
    fi

    echo "Backup successfully transferred to remote storage." | tee -a "$LOG_FILE"
}

# Erweiterung der Backup-Funktion zur Integration von Remote-Backups
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

    transfer_backup_to_remote

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

# Erweiterte Funktion zur umfassenden Prüfung aller Voraussetzungen
check_prerequisites() {
    echo "Performing comprehensive prerequisite check..." | tee -a "$LOG_FILE"
    # 1. Prüfung der MariaDB/MySQL-Installation
    if ! command -v mysql &> /dev/null; then
        handle_error "MySQL/MariaDB is not installed. Please install it first."
    fi
    echo "✅ MySQL/MariaDB is installed." | tee -a "$LOG_FILE"
    # 2. Prüfung der Abhängigkeiten
    local dependencies=("mysqldump" "gzip" "find" "date")
    # Abhängigkeiten basierend auf Konfiguration hinzufügen
    if [ "$ENCRYPT_BACKUPS" == "yes" ]; then
        dependencies+=("gpg")
    fi
    if [ "$COMPRESSION_ALGORITHM" == "bzip2" ]; then
        dependencies+=("bzip2")
    elif [ "$COMPRESSION_ALGORITHM" == "xz" ]; then
        dependencies+=("xz")
    fi
        if [ -n "$REMOTE_RSYNC_TARGET" ]; then
        dependencies+=("rsync")
    fi
    # Prüfung aller benötigten Abhängigkeiten
    local missing_deps=()
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Missing dependencies: ${missing_deps[*]}" | tee -a "$LOG_FILE"
        read -p "Do you want to attempt to install these dependencies? [y/N]: " install_choice
        if [[ "$install_choice" =~ ^[Yy] ]]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y "${missing_deps[@]}"
            elif command -v yum &> /dev/null; then
                sudo yum install -y "${missing_deps[@]}"
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y "${missing_deps[@]}"
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm "${missing_deps[@]}"
            else
                handle_error "Unable to install dependencies automatically. Please install them manually: ${missing_deps[*]}"
            fi
        else
            handle_error "Please install the required dependencies first: ${missing_deps[*]}"
        fi
    fi
    echo "✅ All required dependencies are installed." | tee -a "$LOG_FILE"
    # 3. Überprüfung der Konfiguration
    if [ ! -f "$CONFIG_FILE" ] && [ ! -f "$LOCAL_CONFIG_FILE" ]; then
        echo "Warning: Configuration file not found. Using default values." | tee -a "$LOG_FILE"
    else
        echo "✅ Configuration file exists." | tee -a "$LOG_FILE"
    fi
    # 4. Teste Datenbankverbindung
    echo "Testing database connection..." | tee -a "$LOG_FILE"
    if ! mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
        handle_error "Cannot connect to the database. Please check your credentials and database server."
    fi
    echo "✅ Database connection successful." | tee -a "$LOG_FILE"
    # 5. Prüfung des Backup-Verzeichnisses
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Backup directory does not exist. Creating it..." | tee -a "$LOG_FILE"
        mkdir -p "$BACKUP_DIR" || handle_error "Failed to create backup directory: $BACKUP_DIR"
    fi
    # Teste Schreibrechte im Backup-Verzeichnis
    if [ ! -w "$BACKUP_DIR" ]; then
        handle_error "No write permission to backup directory: $BACKUP_DIR"
    fi
    echo "✅ Backup directory is writable." | tee -a "$LOG_FILE"
    # 6. Überprüfung des verfügbaren Speicherplatzes
    local available_space=$(df -P "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    local min_space=524288  # 512MB in KB
    if [ "$available_space" -lt "$min_space" ]; then
        echo "Warning: Less than 512MB of free space available in backup directory." | tee -a "$LOG_FILE"
        read -p "Continue anyway? [y/N]: " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy] ]]; then
            exit 1
        fi
    fi
    echo "✅ Sufficient disk space available: $(( available_space / 1024 )) MB" | tee -a "$LOG_FILE"
    # 7. Prüfung der Remote-Backup-Konfiguration (falls aktiviert)
    if [ "$REMOTE_BACKUP_ENABLED" == "yes" ]; then
        if [ -n "$REMOTE_NFS_MOUNT" ]; then
            if ! command -v mount &> /dev/null; then
                handle_error "The 'mount' command is required for NFS backup but is not available."
            fi
            echo "✅ NFS mount prerequisites satisfied." | tee -a "$LOG_FILE"
        elif [ -n "$REMOTE_RSYNC_TARGET" ]; then
            if ! command -v rsync &> /dev/null; then
                handle_error "The 'rsync' command is required for remote backup but is not available."
            fi
            echo "✅ rsync prerequisites satisfied." | tee -a "$LOG_FILE"
        elif [ -n "$REMOTE_CLOUD_CLI" ]; then
            if ! command -v "$REMOTE_CLOUD_CLI" &> /dev/null; then
                handle_error "The '$REMOTE_CLOUD_CLI' command is required for cloud backup but is not available."
            fi
            echo "✅ Cloud CLI prerequisites satisfied." | tee -a "$LOG_FILE"
        else
            echo "Warning: Remote backup is enabled but no valid remote target is configured." | tee -a "$LOG_FILE"
        fi
    fi
    echo "All prerequisites checked and satisfied." | tee -a "$LOG_FILE"
}

# Erweiterung der Hauptfunktion für die neue Backup-Integritätsprüfung
case "$1" in
    backup|restore)
        check_prerequisites
        # ...existing code...
        ;;
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    configure)
        configure
        ;;
    update)
        check_for_updates
        ;;
    version)
        echo "mdbackup version $VERSION"
        ;;
    check-updates)
        check_for_updates
        ;;
    install)
        install
        ;;
    uninstall)
        uninstall_script
        ;;
    verify)
        verify_backup_integrity
        ;;
    configure-compression)
        configure_compression
        ;;
    help)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
