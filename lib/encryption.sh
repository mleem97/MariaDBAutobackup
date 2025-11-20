#!/bin/bash
#
# encryption.sh - Verschlüsselungsfunktionen für MariaDBAutobackup
#

# Funktion zur Verschlüsselung von Backups
encrypt_backup() {
    if [ "$ENCRYPT_BACKUPS" == "yes" ] && [ -n "$GPG_KEY_ID" ]; then
        echo "Encrypting backups with GPG key ID: $GPG_KEY_ID..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        find "$BACKUP_PATH" -type f -name "*.sql.gz" | while read -r file; do
            if [ -f "$file" ]; then
                gpg --encrypt --recipient "$GPG_KEY_ID" "$file" && rm "$file"
                echo "Backup file $file encrypted." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
            fi
        done
    elif [ "$ENCRYPT_BACKUPS" == "yes" ] && [ -z "$GPG_KEY_ID" ]; then
        echo "Warning: Encryption is enabled but GPG key ID is not set. Skipping encryption." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    fi
}

# Funktion zur Entschlüsselung von Backups
decrypt_backup() {
    read -p "Do you need to decrypt the backup? (yes/no): " decrypt_choice
    if [ "$decrypt_choice" == "yes" ]; then
        echo "Decrypting backup files..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        # Korrigierter Dateimuster-Check
        for file in "$BACKUP_PATH"/*.gpg; do
            if [ -f "$file" ]; then
                gpg --decrypt --output "${file%.gpg}" "$file" && rm "$file"
                echo "Backup file $file decrypted." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
            else
                echo "No encrypted files found." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
            fi
            break
        done
    fi
}