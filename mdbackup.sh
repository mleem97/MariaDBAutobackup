#!/bin/bash
#
# MariaDBAutobackup (Version 1.1.5)
# Ein umfassendes Skript für die automatisierte Sicherung und Wiederherstellung von MariaDB/MySQL-Datenbanken
#
# Features:
# - Verschiedene Backup-Typen: vollständig, differentiell, inkrementell, tabellen-spezifisch
# - Integritätsprüfung mit Checksummen
# - Konfigurierbare Komprimierung (gzip, bzip2, xz)
# - Verschlüsselung mit GPG
# - Remote-Backups (NFS, rsync, Cloud-Speicher)
# - Pre- und Post-Backup-Hooks
# - Automatische Bereinigung alter Backups
# - Fortschrittsanzeige
# - Umfassende Voraussetzungsprüfung
#
# Autor: mleem97 (https://github.com/mleem97)
# Repository: https://github.com/mleem97/MariaDBAutobackup
# Lizenz: GNU General Public License v3.0

# Versionsinfo
VERSION="1.2.0"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/mleem97/MariaDBAutobackup/main/version.txt"
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/mleem97/MariaDBAutobackup/main/mdbackup.sh"

# Note: Ensure the script has executable permissions before running:
#       chmod +x mdbackup.sh
#       ./mdbackup.sh [command]

# Konfigurationsdatei
CONFIG_FILE="/etc/mdbackup.conf"
LOCAL_CONFIG_FILE="$(dirname "$0")/mdbackup.conf"

# Funktion zum Prüfen des verfügbaren Speicherplatzes - Muss vor dem Hauptbefehlsschalter definiert werden
check_free_space() {
    # Mindestens erforderlicher freier Speicherplatz (in KB)
    local required_space=524288  # 512MB
    
    # Verfügbarer Speicherplatz auf dem Backup-Laufwerk
    local available_space=$(df -P "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        echo "Warning: Less than 512MB free space available on backup directory." | tee -a "$LOG_FILE"
        echo "Available: $(( available_space / 1024 ))MB, Required: $(( required_space / 1024 ))MB" | tee -a "$LOG_FILE"
        read -p "Continue anyway? [y/N]: " choice
        if [[ ! "$choice" =~ ^[Yy] ]]; then
            echo "Backup aborted due to insufficient disk space." | tee -a "$LOG_FILE"
            exit 1
        fi
    fi
    echo "Sufficient disk space available: $(( available_space / 1024 ))MB" | tee -a "$LOG_FILE"
}

# Funktion zum Laden der Konfiguration
load_config() {
    if [ -f "$CONFIG_FILE" ];then
        source "$CONFIG_FILE"
    elif [ -f "$LOCAL_CONFIG_FILE" ];then
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
    REMOTE_BACKUP_ENABLED="${REMOTE_BACKUP_ENABLED:-no}"
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
    }
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

    # Prüfen, ob das Skript bereits installiert ist
    if [ -f "$script_path" ]; then
        echo "mdbackup ist bereits unter $script_path installiert."
        read -p "Möchten Sie die bestehende Installation überschreiben? [J/n]: " overwrite_choice
        overwrite_choice=${overwrite_choice:-J}
        if [[ ! "$overwrite_choice" =~ ^[Jj] ]]; then
            echo "Installation abgebrochen."
            return
        fi
        echo "Bestehende Installation wird überschrieben..."
    fi

    echo "Installiere mdbackup-Skript nach $script_path..."
    sudo cp "$0" "$script_path"
    sudo chmod +x "$script_path"

    # Prüfen, ob der Service bereits existiert
    if [ -f "$service_file" ]; then
        echo "Der systemd-Service existiert bereits und wird aktualisiert."
    else
        echo "Installiere systemd-Service-Datei nach $service_file..."
    fi
    
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

    # Prüfen, ob der Timer bereits existiert
    if [ -f "$timer_file" ]; then
        echo "Der systemd-Timer existiert bereits und wird aktualisiert."
    else
        echo "Installiere systemd-Timer-Datei nach $timer_file..."
    fi
    
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

    echo "Aktiviere und starte den mdbackup-Timer..."
    sudo systemctl daemon-reload
    sudo systemctl enable mdbackup.timer
    sudo systemctl start mdbackup.timer

    echo "Installation abgeschlossen. Das tägliche Backup wird zur in $CONFIG_FILE angegebenen Zeit ausgeführt."
}

# Funktion zur Deinstallation des Skripts und der Systemd-Dateien
uninstall_script() {
    local script_path="/usr/local/bin/mdbackup"
    local service_file="/etc/systemd/system/mdbackup.service"
    local timer_file="/etc/systemd/system/mdbackup.timer"
    local config_file="/etc/mdbackup.conf"
    
    echo "MariaDB Autobackup Deinstallation"
    echo "================================="
    
    read -p "Möchten Sie mdbackup deinstallieren? [j/N]: " uninstall_choice
    uninstall_choice=${uninstall_choice:-N}

    if [[ ! "$uninstall_choice" =~ ^[Jj] ]]; then
        echo "Deinstallation abgebrochen."
        return
    fi
    
    echo "Deinstalliere mdbackup..."
    
    # Stoppen und Deaktivieren des Timers
    if [ -f "$timer_file" ]; then
        echo "Stoppe und deaktiviere den mdbackup-Timer..."
        if [ "$(id -u)" -eq 0 ]; then
            systemctl stop mdbackup.timer 2>/dev/null
            systemctl disable mdbackup.timer 2>/dev/null
        else
            sudo systemctl stop mdbackup.timer 2>/dev/null
            sudo systemctl disable mdbackup.timer 2>/dev/null
        fi
    fi
    
    # Backup-Daten
    read -p "Möchten Sie die vorhandenen Backup-Daten beibehalten? [J/n]: " keep_data
    keep_data=${keep_data:-J}
    
    if [[ ! "$keep_data" =~ ^[Jj] ]] && [ -d "$BACKUP_DIR" ]; then
        echo "Entferne Backup-Daten aus $BACKUP_DIR..."
        if [ "$(id -u)" -eq 0 ]; then
            rm -rf "$BACKUP_DIR"
        else
            sudo rm -rf "$BACKUP_DIR"
        fi
    else
        echo "Backup-Daten werden beibehalten."
    fi
    
    # Konfigurationsdatei
    read -p "Möchten Sie die Konfigurationsdatei entfernen? [j/N]: " remove_config
    remove_config=${remove_config:-N}
    
    if [[ "$remove_config" =~ ^[Jj] ]] && [ -f "$config_file" ]; then
        echo "Entferne Konfigurationsdatei $config_file..."
        if [ "$(id -u)" -eq 0 ]; then
            rm -f "$config_file"
        else
            sudo rm -f "$config_file"
        fi
    else
        echo "Konfigurationsdatei wird beibehalten."
    fi
    
    # Lösche Systemd-Dateien
    echo "Entferne systemd-Service-Dateien..."
    if [ "$(id -u)" -eq 0 ]; then
        rm -f "$service_file" 2>/dev/null
        rm -f "$timer_file" 2>/dev/null
    else
        sudo rm -f "$service_file" 2>/dev/null
        sudo rm -f "$timer_file" 2>/dev/null
    fi
    
    # Lösche das Skript
    echo "Entferne Skript $script_path..."
    if [ "$(id -u)" -eq 0 ]; then
        rm -f "$script_path" 2>/dev/null
    else
        sudo rm -f "$script_path" 2>/dev/null
    fi
    
    # Aktualisiere systemd
    echo "Aktualisiere systemd..."
    if [ "$(id -u)" -eq 0 ]; then
        systemctl daemon-reload
    else
        sudo systemctl daemon-reload
    fi
    
    echo "Deinstallation abgeschlossen."
    echo "Hinweis: Die Logdatei wurde nicht entfernt. Sie befindet sich unter $LOG_FILE."
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
        find "$BACKUP_PATH" -type f -name "*.sql.gz" | while read -r file; do
            if [ -f "$file" ]; then
                gpg --encrypt --recipient "$GPG_KEY_ID" "$file" && rm "$file"
                echo "Backup file $file encrypted." | tee -a "$LOG_FILE"
            fi
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
        # Korrigierter Dateimuster-Check
        for file in "$BACKUP_PATH"/*.gpg; do
            if [ -f "$file" ]; then
                gpg --decrypt --output "${file%.gpg}" "$file" && rm "$file"
                echo "Backup file $file decrypted." | tee -a "$LOG_FILE"
            else
                echo "No encrypted files found." | tee -a "$LOG_FILE"
            fi
            break
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
        "$@"
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
            mysqldump -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") --all-databases > "$BACKUP_PATH/all-databases.sql" || handle_error "Full backup failed!"
            ;;
        differential)
            if [ -z "$last_full_backup" ]; then
                handle_error "No previous full backup found. Please perform a full backup first."
            fi
            echo "Performing differential backup since $last_full_backup..." | tee -a "$LOG_FILE"
            mysqldump -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") --all-databases --flush-logs --master-data=2 --single-transaction --incremental-base-dir="$last_full_backup" > "$BACKUP_PATH/differential.sql" || handle_error "Differential backup failed!"
            ;;
        incremental)
            if [ -z "$last_backup" ]; then
                handle_error "No previous backup found. Please perform a full or differential backup first."
            fi
            echo "Performing incremental backup since $last_backup..." | tee -a "$LOG_FILE"
            mysqldump -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") --all-databases --flush-logs --master-data=2 --single-transaction --incremental-base-dir="$last_backup" > "$BACKUP_PATH/incremental.sql" || handle_error "Incremental backup failed!"
            ;;
        *)
            handle_error "Invalid backup type specified. Use 'full', 'differential', or 'incremental'."
            ;;
    esac

    # Komprimiere die Backup-Dateien mit dem konfigurierten Algorithmus
    compress_backup "$BACKUP_PATH" "$COMPRESSION_ALGORITHM" "$COMPRESSION_LEVEL"
    # Berechne und speichere Prüfsummen für die Backup-Dateien
    calculate_checksum "$BACKUP_PATH"
    
    # Verschlüssele die Backup-Dateien, wenn aktiviert
    encrypt_backup
    
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

    # Korrigiert: Verwendet den konfigurierten Komprimierungsalgorithmus und -level
    compress_backup "$BACKUP_PATH" "$COMPRESSION_ALGORITHM" "$COMPRESSION_LEVEL"
    # Berechnet Prüfsummen für die Backup-Dateien
    calculate_checksum "$BACKUP_PATH"
    
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

    # Überprüfe, ob mindestens eine Remote-Backup-Methode konfiguriert ist
    if [ -z "$REMOTE_NFS_MOUNT" ] && [ -z "$REMOTE_RSYNC_TARGET" ] && 
       [ -z "$REMOTE_CLOUD_CLI" ] || [ -z "$REMOTE_CLOUD_BUCKET" ]; then
        echo "Warning: Remote backup is enabled but no valid method is configured." | tee -a "$LOG_FILE"
        return
    fi

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

    # Wenn die Datenbank nicht lokal ist, prüfen, ob ein SSH-Tunnel benötigt wird
    if [[ "$DATABASE_HOST" != "localhost" && "$DATABASE_HOST" != "127.0.0.1" ]]; then
        connect_to_remote_db || handle_error "Failed to connect to remote database. Backup aborted."
    fi

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

    # SSH-Tunnel schließen, falls er verwendet wurde
    if [ -n "$TUNNEL_PORT" ]; then
        echo "Closing SSH tunnel..." | tee -a "$LOG_FILE"
        pkill -f "ssh -f -N -L $TUNNEL_PORT:localhost:3306"
        DATABASE_HOST="$ORIGINAL_DB_HOST"
        unset TUNNEL_PORT
    fi

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

    # Verbesserte Prüfung auf gültige Backup-Dateien
    if ! ls "$BACKUP_PATH"/*.sql.gz >/dev/null 2>&1 && 
       ! ls "$BACKUP_PATH"/*.sql.gz.gpg >/dev/null 2>&1 && 
       ! ls "$BACKUP_PATH"/*.sql >/dev/null 2>&1; then
        handle_error "No valid backup files found in the specified directory."
    fi

    # Optional: Decrypt the backup
    decrypt_backup

    echo "Restoring backup from $BACKUP_PATH..." | tee -a "$LOG_FILE"
    for file in "$BACKUP_PATH"/*.sql.gz; do
        if [ -f "$file" ]; then
            run_command gunzip -c "$file" | mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") || handle_error "Restore failed for $file!"
        fi
    done
    for file in "$BACKUP_PATH"/*.sql; do
        if [ -f "$file" ]; then
            run_command mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") < "$file" || handle_error "Restore failed for $file!"
        fi
    done

    chown -R mysql:mysql /var/lib/mysql
    chmod -R 755 /var/lib/mysql
    echo "Backup restored from $BACKUP_PATH" | tee -a "$LOG_FILE"
}

# Funktion zur Installation
install() {
    # Starte mit einer umfassenden Überprüfung der Voraussetzungen
    check_prerequisites
    
    read -p "Do you want to install the mdbackup application? [Y/n]: " install_choice
    install_choice=${install_choice:-Y}

    if [[ "$install_choice" =~ ^[Yy] ]]; then
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
    
    # Prüfen, ob curl oder wget verfügbar ist
    if command -v curl &> /dev/null; then
        local remote_version=$(curl -s "$REMOTE_VERSION_URL")
    elif command -v wget &> /dev/null; then
        local remote_version=$(wget -qO- "$REMOTE_VERSION_URL")
    else
        echo "Neither curl nor wget is installed. Cannot check for updates." | tee -a "$LOG_FILE"
        return 1
    }
    
    # Prüfung, ob die Remote-Version erfolgreich abgerufen wurde
    if [ -z "$remote_version" ]; then
        echo "Failed to retrieve remote version information." | tee -a "$LOG_FILE"
        return 1
    }
    
    echo "Current version: $VERSION" | tee -a "$LOG_FILE"
    echo "Latest version: $remote_version" | tee -a "$LOG_FILE"
    
    # Vergleichen der Versionen
    if [ "$remote_version" != "$VERSION" ]; then
        echo "Update available: $remote_version" | tee -a "$LOG_FILE"
        return 0
    else
        echo "You have the latest version." | tee -a "$LOG_FILE"
        return 1
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
    echo "Checking MySQL/MariaDB installation..." | tee -a "$LOG_FILE"
    if ! command -v mysql &> /dev/null; then
        echo "MySQL/MariaDB is not installed." | tee -a "$LOG_FILE"
        read -p "Would you like to install MySQL/MariaDB now? [y/N]: " install_db
        if [[ "$install_db" =~ ^[Yy] ]]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y mariadb-server
            elif command -v yum &> /dev/null; then
                sudo yum install -y mariadb-server
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y mariadb-server
            else
                handle_error "Unable to install MariaDB automatically. Please install it manually."
            fi
            # Starte MariaDB Service
            sudo systemctl enable mariadb
            sudo systemctl start mariadb
            echo "MariaDB installed and started." | tee -a "$LOG_FILE"
        else
            handle_error "MySQL/MariaDB is required but not installed. Please install it first."
        fi
    fi
    echo "✅ MySQL/MariaDB is installed." | tee -a "$LOG_FILE"
    
    # 2. Prüfung der Abhängigkeiten
    echo "Checking required dependencies..." | tee -a "$LOG_FILE"
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
            
            # Überprüfe, ob die Installation erfolgreich war
            local still_missing=()
            for dep in "${missing_deps[@]}"; do
                if ! command -v "$dep" &> /dev/null; then
                    still_missing+=("$dep")
                fi
            done
            
            if [ ${#still_missing[@]} -gt 0 ]; then
                handle_error "Failed to install some dependencies: ${still_missing[*]}"
            fi
        else
            handle_error "Please install the required dependencies first: ${missing_deps[*]}"
        fi
    fi
    echo "✅ All required dependencies are installed." | tee -a "$LOG_FILE"
    
    # 3. Überprüfung der Konfiguration
    echo "Checking configuration file..." | tee -a "$LOG_FILE"
    if [ ! -f "$CONFIG_FILE" ] && [ ! -f "$LOCAL_CONFIG_FILE" ]; then
        echo "Configuration file not found. Setting up initial configuration..." | tee -a "$LOG_FILE"
        read -p "Would you like to configure the application now? [Y/n]: " configure_now
        configure_now=${configure_now:-Y}
        if [[ "$configure_now" =~ ^[Yy] ]]; then
            configure
        else
            echo "Using default configuration values." | tee -a "$LOG_FILE"
        fi
    else
        echo "✅ Configuration file exists." | tee -a "$LOG_FILE"
    fi
    
    # 4. Teste Datenbankverbindung
    echo "Testing database connection..." | tee -a "$LOG_FILE"
    if ! mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
        echo "Cannot connect to the database." | tee -a "$LOG_FILE"
        
        if [ "$DATABASE_HOST" == "localhost" ]; then
            echo "Checking if MariaDB service is running..." | tee -a "$LOG_FILE"
            if command -v systemctl &> /dev/null && ! systemctl is-active --quiet mariadb && ! systemctl is-active --quiet mysql; then
                echo "MariaDB/MySQL service is not running." | tee -a "$LOG_FILE"
                read -p "Would you like to start it now? [Y/n]: " start_db
                start_db=${start_db:-Y}
                if [[ "$start_db" =~ ^[Yy] ]]; then
                    if systemctl list-unit-files | grep -q mariadb; then
                        sudo systemctl start mariadb
                    elif systemctl list-unit-files | grep -q mysql; then
                        sudo systemctl start mysql
                    else
                        handle_error "Could not determine which database service to start."
                    fi
                    echo "Database service started." | tee -a "$LOG_FILE"
                    
                    # Erneut versuchen, die Verbindung herzustellen
                    if ! mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
                        echo "Still cannot connect to the database." | tee -a "$LOG_FILE"
                        read -p "Would you like to update database credentials? [Y/n]: " update_creds
                        update_creds=${update_creds:-Y}
                        if [[ "$update_creds" =~ ^[Yy] ]]; then
                            read -p "Database host [localhost]: " new_host
                            DATABASE_HOST=${new_host:-localhost}
                            read -p "Database user [root]: " new_user
                            DATABASE_USER=${new_user:-root}
                            read -p "Database password: " new_pass
                            DATABASE_PASSWORD="$new_pass"
                            
                            # Konfigurationsdatei aktualisieren
                            if [ -f "$CONFIG_FILE" ]; then
                                sed -i "s/DATABASE_HOST=.*/DATABASE_HOST=\"$DATABASE_HOST\"/" "$CONFIG_FILE"
                                sed -i "s/DATABASE_USER=.*/DATABASE_USER=\"$DATABASE_USER\"/" "$CONFIG_FILE"
                                sed -i "s/DATABASE_PASSWORD=.*/DATABASE_PASSWORD=\"$DATABASE_PASSWORD\"/" "$CONFIG_FILE"
                            elif [ -f "$LOCAL_CONFIG_FILE" ]; then
                                sed -i "s/DATABASE_HOST=.*/DATABASE_HOST=\"$DATABASE_HOST\"/" "$LOCAL_CONFIG_FILE"
                                sed -i "s/DATABASE_USER=.*/DATABASE_USER=\"$DATABASE_USER\"/" "$LOCAL_CONFIG_FILE"
                                sed -i "s/DATABASE_PASSWORD=.*/DATABASE_PASSWORD=\"$DATABASE_PASSWORD\"/" "$LOCAL_CONFIG_FILE"
                            else
                                # Erstelle eine neue Konfigurationsdatei wenn nötig
                                configure
                            fi
                            
                            # Erneut versuchen, die Verbindung herzustellen
                            if ! mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
                                handle_error "Still cannot connect to the database. Please check your credentials and ensure the database server is running."
                            fi
                        else
                            handle_error "Cannot proceed without a working database connection."
                        fi
                    fi
                else
                    handle_error "Cannot proceed with a stopped database service."
                fi
            else
                read -p "Would you like to update database credentials? [Y/n]: " update_creds
                update_creds=${update_creds:-Y}
                if [[ "$update_creds" =~ ^[Yy] ]]; then
                    # Ähnlicher Code wie oben zur Aktualisierung der Anmeldedaten
                    read -p "Database host [localhost]: " new_host
                    DATABASE_HOST=${new_host:-localhost}
                    read -p "Database user [root]: " new_user
                    DATABASE_USER=${new_user:-root}
                    read -p "Database password: " new_pass
                    DATABASE_PASSWORD="$new_pass"
                    
                    # Konfigurationsdatei aktualisieren
                    # ... (wie oben)
                    if [ -f "$CONFIG_FILE" ]; then
                        sed -i "s/DATABASE_HOST=.*/DATABASE_HOST=\"$DATABASE_HOST\"/" "$CONFIG_FILE"
                        sed -i "s/DATABASE_USER=.*/DATABASE_USER=\"$DATABASE_USER\"/" "$CONFIG_FILE"
                        sed -i "s/DATABASE_PASSWORD=.*/DATABASE_PASSWORD=\"$DATABASE_PASSWORD\"/" "$CONFIG_FILE"
                    elif [ -f "$LOCAL_CONFIG_FILE" ]; then
                        sed -i "s/DATABASE_HOST=.*/DATABASE_HOST=\"$DATABASE_HOST\"/" "$LOCAL_CONFIG_FILE"
                        sed -i "s/DATABASE_USER=.*/DATABASE_USER=\"$DATABASE_USER\"/" "$LOCAL_CONFIG_FILE"
                        sed -i "s/DATABASE_PASSWORD=.*/DATABASE_PASSWORD=\"$DATABASE_PASSWORD\"/" "$LOCAL_CONFIG_FILE"
                    else
                        configure
                    fi
                    
                    # Erneut versuchen
                    if ! mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
                        handle_error "Still cannot connect to the database. Please check your credentials and ensure the database server is running."
                    fi
                else
                    handle_error "Cannot proceed without a working database connection."
                fi
            fi
        fi
    fi
    echo "✅ Database connection successful." | tee -a "$LOG_FILE"
    
    # 5. Prüfung des Backup-Verzeichnisses
    echo "Checking backup directory..." | tee -a "$LOG_FILE"
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Backup directory does not exist. Creating it..." | tee -a "$LOG_FILE"
        mkdir -p "$BACKUP_DIR" || handle_error "Failed to create backup directory: $BACKUP_DIR"
    fi
    # Teste Schreibrechte im Backup-Verzeichnis
    if [ ! -w "$BACKUP_DIR" ]; then
        echo "No write permission to backup directory. Attempting to fix permissions..." | tee -a "$LOG_FILE"
        sudo chown -R $(whoami): "$BACKUP_DIR" || handle_error "Failed to set write permissions on backup directory: $BACKUP_DIR"
    fi
    echo "✅ Backup directory is writable." | tee -a "$LOG_FILE"
    
    # 6. Überprüfung des verfügbaren Speicherplatzes
    echo "Checking available disk space..." | tee -a "$LOG_FILE"
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
        echo "Checking remote backup configuration..." | tee -a "$LOG_FILE"
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

# Funktion zur Konfiguration der Anwendung
configure() {
    echo "MariaDB Autobackup Configuration"
    echo "================================"
    # Datenbankeinstellungen
    read -p "Database host [${DATABASE_HOST}]: " input_host
    DATABASE_HOST=${input_host:-$DATABASE_HOST}
    read -p "Database user [${DATABASE_USER}]: " input_user
    DATABASE_USER=${input_user:-$DATABASE_USER}
    read -p "Database password (leave empty for no password): " input_password
    DATABASE_PASSWORD=${input_password:-$DATABASE_PASSWORD}
    # Backup-Einstellungen
    read -p "Backup directory [${BACKUP_DIR}]: " input_backup_dir
    BACKUP_DIR=${input_backup_dir:-$BACKUP_DIR}
    read -p "Log file [${LOG_FILE}]: " input_log_file
    LOG_FILE=${input_log_file:-$LOG_FILE}
    read -p "Backup retention days [${BACKUP_RETENTION_DAYS}]: " input_retention
    BACKUP_RETENTION_DAYS=${input_retention:-$BACKUP_RETENTION_DAYS}
    # Verschlüsselungseinstellungen
    read -p "Encrypt backups (yes/no) [${ENCRYPT_BACKUPS}]: " input_encrypt
    ENCRYPT_BACKUPS=${input_encrypt:-$ENCRYPT_BACKUPS}
    if [ "$ENCRYPT_BACKUPS" == "yes" ]; then
        read -p "GPG key ID [${GPG_KEY_ID}]: " input_gpg_key
        GPG_KEY_ID=${input_gpg_key:-$GPG_KEY_ID}
    fi
    # Zeitplaneinstellungen
    read -p "Backup time (HH:MM) [${BACKUP_TIME}]: " input_time
    BACKUP_TIME=${input_time:-$BACKUP_TIME}
    # Remote Backup-Einstellungen
    read -p "Enable remote backup (yes/no) [${REMOTE_BACKUP_ENABLED:-no}]: " input_remote
    REMOTE_BACKUP_ENABLED=${input_remote:-${REMOTE_BACKUP_ENABLED:-no}}
    
    if [ "$REMOTE_BACKUP_ENABLED" == "yes" ]; then
        echo "Select remote backup type:"
        echo "1) NFS Mount"
        echo "2) Rsync Target"
        echo "3) Cloud Storage"
        read -p "Choose a type [1-3]: " remote_type
        
        case $remote_type in
            1)
                read -p "NFS mount point: " REMOTE_NFS_MOUNT
                REMOTE_RSYNC_TARGET=""
                REMOTE_CLOUD_CLI=""
                REMOTE_CLOUD_BUCKET=""
                ;;
            2)
                read -p "Rsync target (user@host:/path): " REMOTE_RSYNC_TARGET
                REMOTE_NFS_MOUNT=""
                REMOTE_CLOUD_CLI=""
                REMOTE_CLOUD_BUCKET=""
                ;;
            3)
                read -p "Cloud CLI command (aws, gsutil, etc): " REMOTE_CLOUD_CLI
                read -p "Cloud bucket path (s3://bucket, gs://bucket): " REMOTE_CLOUD_BUCKET
                REMOTE_NFS_MOUNT=""
                REMOTE_RSYNC_TARGET=""
                ;;
            *)
                echo "Invalid choice. Remote backup will be disabled."
                REMOTE_BACKUP_ENABLED="no"
                ;;
        esac
    fi
    
    # Komprimierungseinstellungen
    echo "Select compression algorithm:"
    echo "1) gzip (fastest, moderate compression)"
    echo "2) bzip2 (slower, better compression)"
    echo "3) xz (slowest, best compression)"
    read -p "Choose algorithm [1-3] [1]: " comp_choice
    
    case ${comp_choice:-1} in
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
            echo "Invalid choice. Using gzip."
            COMPRESSION_ALGORITHM="gzip"
            ;;
    esac
    
    read -p "Compression level (1-9) [${COMPRESSION_LEVEL:-6}]: " comp_level
    COMPRESSION_LEVEL=${comp_level:-${COMPRESSION_LEVEL:-6}}
    
    # Konfiguration speichern
    echo "Saving configuration to $CONFIG_FILE..."
    
    # Stellen Sie sicher, dass das Verzeichnis existiert
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Erstellen oder aktualisieren Sie die Konfigurationsdatei
    cat > "$CONFIG_FILE" << EOF
# MariaDB Autobackup Configuration
# Generated on $(date)

# Database Settings
DATABASE_HOST="$DATABASE_HOST"
DATABASE_USER="$DATABASE_USER"
DATABASE_PASSWORD="$DATABASE_PASSWORD"

# Backup Settings
BACKUP_DIR="$BACKUP_DIR"
LOG_FILE="$LOG_FILE"
BACKUP_RETENTION_DAYS="$BACKUP_RETENTION_DAYS"

# Compression Settings
COMPRESSION_ALGORITHM="$COMPRESSION_ALGORITHM"
COMPRESSION_LEVEL="$COMPRESSION_LEVEL"

# Encryption Settings
ENCRYPT_BACKUPS="$ENCRYPT_BACKUPS"
GPG_KEY_ID="$GPG_KEY_ID"

# Schedule Settings
BACKUP_TIME="$BACKUP_TIME"

# Remote Backup Settings
REMOTE_BACKUP_ENABLED="$REMOTE_BACKUP_ENABLED"
REMOTE_NFS_MOUNT="$REMOTE_NFS_MOUNT"
REMOTE_RSYNC_TARGET="$REMOTE_RSYNC_TARGET"
REMOTE_CLOUD_CLI="$REMOTE_CLOUD_CLI"
REMOTE_CLOUD_BUCKET="$REMOTE_CLOUD_BUCKET"
EOF
    
    echo "Configuration has been saved."
}

# Erweiterung der Hauptfunktion für die neue Backup-Integritätsprüfung
case "$1" in
    backup)
        check_prerequisites
        check_free_space
        backup
        ;;
    restore)
        check_prerequisites
        restore
        ;;
    configure)
        configure
        ;;
    update)
        update_script
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
    create-service)
        create_service
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

update_script() {
    echo "Checking for updates..." | tee -a "$LOG_FILE"
    
    local update_available=false
    check_for_updates && update_available=true
    
    if [ "$update_available" = false ]; then
        echo "No updates available. Your script is already up to date." | tee -a "$LOG_FILE"
        return
    fi
    
    # Sicherstellen, dass wir ein Skript downloaden können
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo "Error: Neither curl nor wget is available. Cannot perform update." | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Backup des aktuellen Skripts erstellen
    local script_path="$(realpath "$0")"
    local backup_path="${script_path}.backup-$(date +%Y%m%d%H%M%S)"
    
    echo "Creating backup of current script at $backup_path..." | tee -a "$LOG_FILE"
    cp "$script_path" "$backup_path" || { 
        echo "Failed to create backup. Aborting update." | tee -a "$LOG_FILE"
        return 1
    }
    
    # Download des neuen Skripts
    echo "Downloading latest version..." | tee -a "$LOG_FILE"
    local temp_file=$(mktemp)
    
    if command -v curl &> /dev/null; then
        curl -s -o "$temp_file" "$REMOTE_SCRIPT_URL"
    else
        wget -q -O "$temp_file" "$REMOTE_SCRIPT_URL"
    fi
    
    # Überprüfen, ob der Download erfolgreich war
    if [ ! -s "$temp_file" ]; then
        echo "Failed to download the latest version. Restoring backup..." | tee -a "$LOG_FILE"
        mv "$backup_path" "$script_path"
        rm -f "$temp_file"
        return 1
    fi
    
    # Überprüfen, ob das heruntergeladene Skript ein gültiges Bash-Skript ist
    if ! head -n 1 "$temp_file" | grep -q "#!/bin/bash"; then
        echo "Downloaded file does not appear to be a valid bash script. Restoring backup..." | tee -a "$LOG_FILE"
        mv "$backup_path" "$script_path"
        rm -f "$temp_file"
        return 1
    fi
    
    # Vergleiche Versionsinformationen
    local new_version=$(grep "^VERSION=" "$temp_file" | head -n 1 | cut -d'"' -f2)
    echo "New version: $new_version" | tee -a "$LOG_FILE"
    
    # Überschreibe das Skript mit der neuen Version
    echo "Installing new version..." | tee -a "$LOG_FILE"
    mv "$temp_file" "$script_path"
    chmod +x "$script_path"
    
    # Überprüfe, ob eine Installation vorhanden ist und aktualisiere sie
    local installed_path="/usr/local/bin/mdbackup"
    if [ -f "$installed_path" ]; then
        echo "Detected installed version. Updating system-wide installation..." | tee -a "$LOG_FILE"
        
        # Überprüfe, ob wir sudo-Rechte haben oder das Skript als Root ausgeführt wird
        if [ "$(id -u)" -eq 0 ] || command -v sudo &> /dev/null; then
            if [ "$(id -u)" -eq 0 ]; then
                cp "$script_path" "$installed_path"
                chmod +x "$installed_path"
            else
                sudo cp "$script_path" "$installed_path"
                sudo chmod +x "$installed_path"
            fi
            echo "System-wide installation updated." | tee -a "$LOG_FILE"
            
            # Neustart des Timers, falls vorhanden
            if [ -f "/etc/systemd/system/mdbackup.timer" ]; then
                echo "Restarting the mdbackup timer..." | tee -a "$LOG_FILE"
                if [ "$(id -u)" -eq 0 ]; then
                    systemctl daemon-reload
                    systemctl restart mdbackup.timer
                else
                    sudo systemctl daemon-reload
                    sudo systemctl restart mdbackup.timer
                fi
                echo "Timer restarted." | tee -a "$LOG_FILE"
            fi
        else
            echo "Warning: Cannot update system-wide installation without sudo privileges." | tee -a "$LOG_FILE"
        fi
    fi
    
    echo "Update completed successfully!" | tee -a "$LOG_FILE"
    echo "New version: $new_version" | tee -a "$LOG_FILE"
    echo "Previous version: $VERSION" | tee -a "$LOG_FILE"
    echo "Backup saved at: $backup_path" | tee -a "$LOG_FILE"
    echo "To revert to the previous version, run: mv \"$backup_path\" \"$script_path\"" | tee -a "$LOG_FILE"
}

create_service() {
    echo "Creating and configuring systemd service for mdbackup..." | tee -a "$LOG_FILE"
    
    local script_path="/usr/local/bin/mdbackup"
    local service_file="/etc/systemd/system/mdbackup.service"
    local timer_file="/etc/systemd/system/mdbackup.timer"
    
    # Prüfe, ob systemd verfügbar ist
    if ! command -v systemctl &> /dev/null; then
        echo "Error: systemd is not available on this system. Cannot create service." | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Service-Datei erstellen oder aktualisieren
    echo "Creating systemd service file at $service_file..." | tee -a "$LOG_FILE"
    
    cat > /tmp/mdbackup.service << EOF
[Unit]
Description=MariaDB/MySQL Automatic Backup Service
After=network.target mysql.service mariadb.service
Wants=mysql.service mariadb.service

[Service]
Type=oneshot
User=root
Group=root
ExecStart=$script_path backup
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
SuccessExitStatus=0
TimeoutStartSec=1200
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /tmp/mdbackup.service "$service_file"
    
    # Timer-Datei erstellen oder aktualisieren
    echo "Creating systemd timer file at $timer_file..." | tee -a "$LOG_FILE"
    
    # Lese die BACKUP_TIME aus der Konfiguration
    BACKUP_TIME="${BACKUP_TIME:-02:00}"
    
    cat > /tmp/mdbackup.timer << EOF
[Unit]
Description=Daily MariaDB/MySQL Backup Timer
After=network.target

[Timer]
OnCalendar=*-*-* $BACKUP_TIME
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

    sudo mv /tmp/mdbackup.timer "$timer_file"
    
    # systemd neu laden
    echo "Reloading systemd configuration..." | tee -a "$LOG_FILE"
    sudo systemctl daemon-reload
    
    # Timer aktivieren und starten
    echo "Enabling and starting mdbackup timer..." | tee -a "$LOG_FILE"
    sudo systemctl enable mdbackup.timer
    sudo systemctl start mdbackup.timer
    
    # Servicesstatus anzeigen
    echo "Service information:" | tee -a "$LOG_FILE"
    echo "-------------------" | tee -a "$LOG_FILE"
    echo "Next execution time:" | tee -a "$LOG_FILE"
    sudo systemctl list-timers mdbackup.timer | grep mdbackup || echo "Timer not found."
    
    # Überprüfen, ob der Timer korrekt aktiviert wurde
    if sudo systemctl is-enabled --quiet mdbackup.timer; then
        echo "✅ mdbackup service and timer successfully created and activated." | tee -a "$LOG_FILE"
        echo "The backup will run daily at $BACKUP_TIME." | tee -a "$LOG_FILE"
    else
        echo "⚠️ Warning: Could not enable the timer service." | tee -a "$LOG_FILE"
        return 1
    fi
    
    return 0
}

connect_to_remote_db() {
    echo "Testing connection to remote database at $DATABASE_HOST..." | tee -a "$LOG_FILE"
    
    # Prüfen, ob ein SSH-Tunnel benötigt wird
    local need_ssh=false
    if [[ "$DATABASE_HOST" != "localhost" && "$DATABASE_HOST" != "127.0.0.1" ]]; then
        read -p "Do you need an SSH tunnel to connect to $DATABASE_HOST? [y/N]: " use_ssh
        if [[ "$use_ssh" =~ ^[Yy] ]]; then
            need_ssh=true
            # Prüfen, ob die SSH-Einstellungen konfiguriert sind
            if [ -z "$SSH_USER" ] || [ -z "$SSH_HOST" ]; then
                read -p "SSH username for database server: " SSH_USER
                read -p "SSH hostname for database server: " SSH_HOST
                read -p "SSH port [22]: " SSH_PORT
                SSH_PORT=${SSH_PORT:-22}
                
                # SSH-Einstellungen in die Konfiguration speichern
                if [ -f "$CONFIG_FILE" ]; then
                    echo "SSH_USER=\"$SSH_USER\"" >> "$CONFIG_FILE"
                    echo "SSH_HOST=\"$SSH_HOST\"" >> "$CONFIG_FILE"
                    echo "SSH_PORT=\"$SSH_PORT\"" >> "$CONFIG_FILE"
                elif [ -f "$LOCAL_CONFIG_FILE" ]; then
                    echo "SSH_USER=\"$SSH_USER\"" >> "$LOCAL_CONFIG_FILE"
                    echo "SSH_HOST=\"$SSH_HOST\"" >> "$LOCAL_CONFIG_FILE"
                    echo "SSH_PORT=\"$SSH_PORT\"" >> "$LOCAL_CONFIG_FILE"
                fi
            fi
            
            # Prüfen, ob ssh verfügbar ist
            if ! command -v ssh &> /dev/null; then
                handle_error "SSH is required but not installed. Please install OpenSSH client."
            fi
            
            # Aufbau des SSH-Tunnels
            echo "Setting up SSH tunnel to $SSH_HOST..." | tee -a "$LOG_FILE"
            local tunnel_port=13306  # Temporärer Port für den Tunnel
            ssh -f -N -L $tunnel_port:localhost:3306 -p $SSH_PORT $SSH_USER@$SSH_HOST
            
            if [ $? -ne 0 ]; then
                handle_error "Failed to establish SSH tunnel. Check your SSH credentials."
            fi
            
            echo "SSH tunnel established on local port $tunnel_port" | tee -a "$LOG_FILE"
            # Temporär den Datenbank-Host auf den Tunnel umleiten
            ORIGINAL_DB_HOST="$DATABASE_HOST"
            DATABASE_HOST="127.0.0.1"
            TUNNEL_PORT="$tunnel_port"
        fi
    fi
    
    # Datenbankverbindung testen
    if mysql -h "$DATABASE_HOST" -P "${TUNNEL_PORT:-3306}" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
        echo "✅ Successfully connected to database at $ORIGINAL_DB_HOST" | tee -a "$LOG_FILE"
        return 0
    else
        echo "❌ Failed to connect to database at $ORIGINAL_DB_HOST" | tee -a "$LOG_FILE"
        
        # Wenn ein SSH-Tunnel verwendet wurde, diesen wieder schließen
        if [ "$need_ssh" = true ]; then
            echo "Closing SSH tunnel..." | tee -a "$LOG_FILE"
            pkill -f "ssh -f -N -L $TUNNEL_PORT:localhost:3306"
            DATABASE_HOST="$ORIGINAL_DB_HOST"
            unset TUNNEL_PORT
        fi
        
        return 1
    fi
}
