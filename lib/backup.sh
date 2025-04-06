#!/bin/bash
#
# backup.sh - Backup-Funktionen für MariaDBAutobackup
#

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
    
    chown -R mysql:mysql "$BACKUP_PATH" 2>/dev/null || true
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
    
    chown -R mysql:mysql "$BACKUP_PATH" 2>/dev/null || true
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

# Funktion zur Bereinigung alter Backups
cleanup_old_backups() {
    echo "Cleaning up backups older than $BACKUP_RETENTION_DAYS days in $BACKUP_DIR..." | tee -a "$LOG_FILE"
    find "$BACKUP_DIR" -type d -name "backup-*" -mtime +"$BACKUP_RETENTION_DAYS" -exec rm -rf {} \; | tee -a "$LOG_FILE"
    echo "Old backups cleaned up." | tee -a "$LOG_FILE"
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
    
    # Alte Backups aufräumen
    cleanup_old_backups
}