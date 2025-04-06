#!/bin/bash
#
# remote.sh - Remote-Backup-Funktionen für MariaDBAutobackup
#

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