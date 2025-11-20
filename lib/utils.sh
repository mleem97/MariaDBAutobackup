#!/bin/bash
#
# utils.sh - Hilfsfunktionen für MariaDBAutobackup
#

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

# Funktion zur Fehlerbehandlung
handle_error() {
    echo "Error: $1" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    exit 1
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

# Funktion zur Fortschrittsanzeige
show_progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    printf "\rProgress: [%-50s] %d%%" $(printf "#%.0s" $(seq 1 $((percent / 2)))) $percent
}