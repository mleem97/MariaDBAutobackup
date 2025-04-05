#!/bin/bash

# Note: Ensure the script has executable permissions before running:
#       chmod +x mdbackup.sh
#       ./mdbackup.sh [command]

VERSION="1.1.0" # Aktualisierte Skriptversion
REMOTE_VERSION_URL="https://raw.githubusercontent.com/mleem97/MariaDBAutobackup/main/version.txt"

# Konfigurationsdatei
CONFIG_FILE="/etc/mdbackup.conf"
LOCAL_CONFIG_FILE="$(dirname "$0")/mdbackup.conf"

# Funktion zum Laden der Konfiguration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    elif [ -f "$LOCAL_CONFIG_FILE" ]; then
        source "<span class="math-inline">LOCAL\_CONFIG\_FILE"
else
echo "Warning\: Configuration file not found\. Using default values\."
fi
\# Setze Standardwerte, falls in der Konfiguration nicht vorhanden
DATABASE\_HOST\="</span>{DATABASE_HOST:-localhost}"
    DATABASE_USER="<span class="math-inline">\{DATABASE\_USER\:\-root\}"
BACKUP\_DIR\="</span>{BACKUP_DIR:-/var/lib/mysql-backups}"
    LOG_FILE="<span class="math-inline">\{LOG\_FILE\:\-/var/log/mdbackup\.log\}"
BACKUP\_RETENTION\_DAYS\="</span>{BACKUP_RETENTION_DAYS:-7}"
    GZIP_COMPRESSION_LEVEL="<span class="math-inline">\{GZIP\_COMPRESSION\_LEVEL\:\-6\}"
ENCRYPT\_BACKUPS\="</span>{ENCRYPT_BACKUPS:-no}"
    GPG_KEY_ID="<span class="math-inline">\{GPG\_KEY\_ID\:\-\}"
BACKUP\_TIME\="</span>{BACKUP_TIME:-02:00}"
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
    echo "  help            Display this help message"
}

# Funktion zur Überprüfung, ob MariaDB oder MySQL installiert ist
check_mariadb_mysql_installed() {
    if command -v mysql &> /dev/null; then
        echo "MySQL/MariaDB is installed."
    else
        echo "MySQL/MariaDB is not installed. Please install it first."
        exit 1
    fi
}

# Funktion zur Überprüfung von Abhängigkeiten
check_dependencies() {
    local dependencies=("mysqldump" "gzip" "gunzip")
    if [ "$ENCRYPT_BACKUPS" == "yes" ]; then
        dependencies+=("gpg")
    fi
    if [ "<span class="math-inline">1" \=\= "install" \]; then
dependencies\+\=\("systemctl"\)
fi
for dep in "</span>{dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Error: Required dependency '$dep' is not installed. Please install it first."
            exit 1
        fi
    done
}

# Funktion zur Überprüfung und Installation von Abhängigkeiten
check_and_install_dependencies() {
    local dependencies=("mysqldump" "gzip" "gunzip")
    if [ "<span class="math-inline">ENCRYPT\_BACKUPS" \=\= "yes" \]; then
dependencies\+\=\("gpg"\)
fi
<0\>local missing\_dependencies\=\(\)
for dep <1\>in "</span>{dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_dependencies+=("$dep")
        fi
    done

    if [ ${#missing_dependencies[@]} -eq 0 ]; then
        echo "All necessary dependencies are already installed."
        return
    fi

    echo "The following dependencies are missing: <span class="math-inline">\{missing\_dependencies\[\*\]\}"
read \-p "Do you want to install them now? \[Y/n\]\: " install\_choice
install\_choice\=</span>{install_choice:-Y}

    if [[ "<span class="math-inline">install\_choice" \=\~ ^\[Yy\]</span> ]]; then
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

    echo "Installing mdbackup script to $script_path..."
    sudo cp "$0" "$script_path"
    sudo chmod +x "$script_path"

    echo "Installing systemd service file to $service_file..."
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

    echo "Installing systemd timer file to $timer_file..."
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

    echo "Enabling and starting the mdbackup timer..."
    sudo systemctl daemon-reload
    sudo systemctl enable mdbackup.timer
    sudo systemctl start mdbackup.timer

    echo "Installation completed. The daily backup will run at the time specified in <span class="math-inline">CONFIG\_FILE\."
\}
\# Funktion zur Deinstallation des Skripts und der Systemd\-Dateien
uninstall\_script\(\) \{
local script\_path\="/usr/local/bin/mdbackup"
local service\_file\="/etc/systemd/system/mdbackup\.service"
local timer\_file\="/etc/systemd/system/mdbackup\.timer"
read \-p "Are you sure you want to uninstall mdbackup? This will stop the timer and remove the script and service files\. \[Y/n\]\: " uninstall\_choice
uninstall\_choice\=</span>{uninstall_choice:-N}

    if [[ "<span class="math-inline">uninstall\_choice" \=\~ ^\[Yy\]</span> ]]; then
        echo "Stopping and disabling the mdbackup timer..."
        sudo systemctl stop mdbackup.timer
        sudo systemctl disable mdbackup.timer

        echo "Removing systemd service file $service_file..."
        sudo rm -f "$service_file"

        echo "Removing systemd timer file $timer_file..."
        sudo rm -f "$timer_file"

        echo "Removing script $script_path..."
        sudo rm -f "$script_path"

        sudo systemctl daemon-reload
        echo "Uninstallation completed."
    else
        echo "Uninstallation aborted."
    fi
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
        for file in "$BACKUP_PATH"/*.sql.gz; do
            gpg --encrypt --recipient "$GPG_KEY_ID" "$file" && rm "$file"
            echo "Backup file $file encrypted." | tee -a "$LOG_FILE"
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
        for file in "<span class="math-inline">BACKUP\_PATH"/\*\.sql\.gz\.gpg; do
gpg \-\-decrypt \-\-output "</span>{file%.gpg}" "$file" && rm "$file"
            echo "Backup file $file decrypted." | tee -a "$LOG_FILE"
        done
    fi
}

# Testmodus aktivieren
TEST_MODE=false

# Wrapper für Befehle im Testmodus
run_command() {
    if [ "$TEST_MODE" == "true" ]; then
        echo "[TEST MODE] <span class="math-inline">\*"
else
eval "</span>@"
    fi
}

# Funktion zur Bereinigung alter Backups
cleanup_old_backups() {
    echo "Cleaning up backups older than $BACKUP_RETENTION_DAYS days in $BACKUP_DIR..." | tee -a "$LOG_FILE"
    find "$BACKUP_DIR" -type d -name "backup-*" -mtime +"$BACKUP_RETENTION_DAYS" -exec rm -rf {} \; | tee -a "$LOG_FILE"
    echo "Old backups cleaned up." | tee -a "$LOG_FILE"
}

# Erweiterte Backup-Funktion mit Verschlüsselung
backup() {
    echo "Creating backup..." | tee -a "<span class="math-inline">LOG\_FILE"
TIMESTAMP\=</span>(date +"%F_%T")
    BACKUP_PATH="$BACKUP_DIR/backup-$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"

    read -p "Do you want to backup all databases? (yes/no): " all_dbs
    if [ "$all_dbs" == "yes" ]; then
        run_command mysqldump -h "$DATABASE_HOST" -u "$DATABASE_USER" "$DATABASE_PASSWORD" --all-databases > "$BACKUP_PATH/all-databases.sql" || handle_error "Backup failed!"
    else
        read -p "Enter the database name to backup: " db_name
        run_command mysqldump -h "$DATABASE_HOST" -u "$DATABASE_USER" "$DATABASE_PASSWORD" "$db_name" > "$BACKUP_PATH/<span class="math-inline">db\_name\.sql" \|\| handle\_error "Backup failed\!"
fi
run\_command gzip \-"</span>{GZIP_COMPRESSION_LEVEL}" "$BACKUP_PATH"/*.sql
    chown -R mysql:mysql "$BACKUP_PATH"
    chmod -R 755 "$BACKUP_PATH"
    echo "Backup created at $BACKUP_PATH" | tee -a "$LOG_FILE"

    # Optional: Encrypt the backup
    encrypt_backup

    # Cleanup old backups
    cleanup_old_backups
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

    if [ ! -f "$BACKUP_PATH/all-databases.sql.gz" ] && [ ! -f "$BACKUP_PATH/*.sql.gz.gpg" ] && [ ! -f "$BACKUP_PATH/*.sql.gz" ]; then
        handle_error "No valid backup files found in the specified directory."
    fi

    # Optional: Decrypt the backup
    decrypt_backup

    echo "Restoring backup from $BACKUP_PATH..." | tee -a "$LOG_FILE"
    for file in "$BACKUP_PATH"/*.sql.gz; do
        run_command gunzip -c "$file" | mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" "$DATABASE_PASSWORD" || handle_error "Restore failed for $file!"
    done
    for file in "$BACKUP_PATH"/*.sql; do
        run_command mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" "$DATABASE_PASSWORD" < "$file" || handle_error "Restore failed for $file!"
    done

    chown -R mysql:mysql /var/lib/mysql
    chmod -R 755 /var/lib/mysql
    echo "Backup restored from $BACKUP_PATH" | tee -a "$LOG_FILE"
}

# Funktion zur Installation
install() {
    read -p "Do you want to install the mdbackup application?