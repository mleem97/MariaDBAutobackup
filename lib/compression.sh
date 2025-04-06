#!/bin/bash
#
# compression.sh - Komprimierungsfunktionen für MariaDBAutobackup
#

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