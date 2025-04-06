#!/bin/bash
#
# config.sh - Konfigurationsfunktionen für MariaDBAutobackup
#

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
    LOG_FILE="${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
    COMPRESSION_ALGORITHM="${COMPRESSION_ALGORITHM:-gzip}"
    COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-6}"
    ENCRYPT_BACKUPS="${ENCRYPT_BACKUPS:-no}"
    GPG_KEY_ID="${GPG_KEY_ID:-}"
    BACKUP_TIME="${BACKUP_TIME:-02:00}"
    REMOTE_BACKUP_ENABLED="${REMOTE_BACKUP_ENABLED:-no}"
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