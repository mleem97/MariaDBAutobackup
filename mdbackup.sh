#!/bin/bash
#
# MariaDBAutobackup (Version 1.2.1)
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

# Basisverzeichnis bestimmen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
CONF_DIR="$SCRIPT_DIR/conf"
LOG_DIR="$SCRIPT_DIR/logs"

# Versionsinfo
VERSION="1.2.1"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/mleem97/MariaDBAutobackup/main/version.txt"
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/mleem97/MariaDBAutobackup/main/mdbackup.sh"

# Konfigurationsdatei
CONFIG_FILE="$CONF_DIR/mdbackup.conf"
LOCAL_CONFIG_FILE="$SCRIPT_DIR/mdbackup.conf"

# Verzeichnisstruktur sicherstellen
mkdir -p "$LIB_DIR" "$CONF_DIR" "$LOG_DIR"

# Module laden
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/prerequisites.sh"
source "$LIB_DIR/backup.sh"
source "$LIB_DIR/restore.sh"
source "$LIB_DIR/verify.sh"
source "$LIB_DIR/compression.sh"
source "$LIB_DIR/encryption.sh"
source "$LIB_DIR/remote.sh"
source "$LIB_DIR/system.sh"

# Hauptbefehlsschalter
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