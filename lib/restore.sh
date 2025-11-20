#!/bin/bash
#
# restore.sh - Wiederherstellungsfunktionen für MariaDBAutobackup
#

# Erweiterte Restore-Funktion mit Entschlüsselung
restore() {
    echo "Available backups in $BACKUP_DIR:" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    ls "$BACKUP_DIR" | grep "backup-" || { echo "No backups found." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"; exit 1; }

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

    echo "Restoring backup from $BACKUP_PATH..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
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

    chown -R mysql:mysql /var/lib/mysql 2>/dev/null || true
    chmod -R 755 /var/lib/mysql 2>/dev/null || true
    echo "Backup restored from $BACKUP_PATH" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
}