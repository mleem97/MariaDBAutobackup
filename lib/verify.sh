#!/bin/bash
#
# verify.sh - Überprüfungsfunktionen für MariaDBAutobackup
#

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