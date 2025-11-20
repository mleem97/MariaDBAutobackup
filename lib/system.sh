#!/bin/bash
#
# system.sh - Systemfunktionen für MariaDBAutobackup
#

# Funktion zur Installation des Skripts und der Systemd-Dateien
install_script() {
    local script_path="/usr/local/bin/mdbackup"
    local service_file="/etc/systemd/system/mdbackup.service"
    local timer_file="/etc/systemd/system/mdbackup.timer"

    # Prüfen, ob das Skript bereits installiert ist
    if [ -f "$script_path" ]; then
        echo "mdbackup ist bereits unter $script_path installiert."
        read -p "Möchten Sie die bestehende Installation überschreiben? [J/n]: " overwrite_choice
        overwrite_choice=${overwrite_choice:-J}
        if [[ ! "$overwrite_choice" =~ ^[Jj] ]]; then
            echo "Installation abgebrochen."
            return
        fi
        echo "Bestehende Installation wird überschrieben..."
    fi

    echo "Installiere mdbackup-Skript nach $script_path..."
    sudo cp "$SCRIPT_DIR/mdbackup.sh" "$script_path"
    sudo chmod +x "$script_path"
    
    # Sicherstellen, dass das lib-Verzeichnis kopiert wird
    sudo mkdir -p "$(dirname "$script_path")/lib"
    sudo cp -r "$LIB_DIR"/* "$(dirname "$script_path")/lib/"

    # Stellen sicher, dass die Konfigurationsdatei in /etc existiert
    local system_config_file="/etc/mdbackup.conf"
    if [ ! -f "$system_config_file" ]; then
        echo "Kopiere Konfigurationsdatei nach $system_config_file..."
        sudo cp "$CONFIG_FILE" "$system_config_file"
    fi

    # Setze LOG_FILE auf einen Standardwert für den systemd-Service
    if [ -z "$LOG_FILE" ]; then
        LOG_FILE="/var/log/mdbackup.log"
    fi

    # Setze BACKUP_TIME auf einen Standardwert für den systemd-Timer
    if [ -z "$BACKUP_TIME" ]; then
        BACKUP_TIME="02:00"
    fi

    # Prüfen, ob der Service bereits existiert
    if [ -f "$service_file" ]; then
        echo "Der systemd-Service existiert bereits und wird aktualisiert."
    else
        echo "Installiere systemd-Service-Datei nach $service_file..."
    fi
    
    echo "[Unit]" | sudo tee "$service_file"
    echo "Description=MariaDB/MySQL Automatic Backup Service" | sudo tee -a "$service_file"
    echo "After=network.target mysql.service mariadb.service" | sudo tee -a "$service_file"
    echo "Wants=mysql.service mariadb.service" | sudo tee -a "$service_file"
    echo "" | sudo tee -a "$service_file"
    echo "[Service]" | sudo tee -a "$service_file"
    echo "User=root" | sudo tee -a "$service_file"
    echo "Group=root" | sudo tee -a "$service_file"
    echo "Type=oneshot" | sudo tee -a "$service_file"
    echo "EnvironmentFile=$system_config_file" | sudo tee -a "$service_file"
    echo "ExecStart=$script_path backup" | sudo tee -a "$service_file"
    echo "StandardOutput=append:$LOG_FILE" | sudo tee -a "$service_file"
    echo "StandardError=append:$LOG_FILE" | sudo tee -a "$service_file"
    echo "" | sudo tee -a "$service_file"
    echo "[Install]" | sudo tee -a "$service_file"
    echo "WantedBy=multi-user.target" | sudo tee -a "$service_file"

    # Prüfen, ob der Timer bereits existiert
    if [ -f "$timer_file" ]; then
        echo "Der systemd-Timer existiert bereits und wird aktualisiert."
    else
        echo "Installiere systemd-Timer-Datei nach $timer_file..."
    fi
    
    echo "[Unit]" | sudo tee "$timer_file"
    echo "Description=Daily MariaDB/MySQL Backup Timer" | sudo tee -a "$timer_file"
    echo "After=network.target" | sudo tee -a "$timer_file"
    echo "" | sudo tee -a "$timer_file"
    echo "[Timer]" | sudo tee -a "$timer_file"
    echo "OnCalendar=*-*-* $BACKUP_TIME" | sudo tee -a "$timer_file"
    echo "Persistent=true" | sudo tee -a "$timer_file"
    echo "" | sudo tee -a "$timer_file"
    echo "[Install]" | sudo tee -a "$timer_file"
    echo "WantedBy=timers.target" | sudo tee -a "$timer_file"

    echo "Aktiviere und starte den mdbackup-Timer..."
    sudo systemctl daemon-reload
    sudo systemctl enable mdbackup.timer
    sudo systemctl start mdbackup.timer

    echo "Installation abgeschlossen. Das tägliche Backup wird um $BACKUP_TIME Uhr ausgeführt."
}

# Funktion zur Deinstallation des Skripts und der Systemd-Dateien
uninstall_script() {
    local script_path="/usr/local/bin/mdbackup"
    local service_file="/etc/systemd/system/mdbackup.service"
    local timer_file="/etc/systemd/system/mdbackup.timer"
    local config_file="/etc/mdbackup.conf"
    
    echo "MariaDB Autobackup Deinstallation"
    echo "================================="
    
    read -p "Möchten Sie mdbackup deinstallieren? [j/N]: " uninstall_choice
    uninstall_choice=${uninstall_choice:-N}

    if [[ ! "$uninstall_choice" =~ ^[Jj] ]]; then
        echo "Deinstallation abgebrochen."
        return
    fi
    
    echo "Deinstalliere mdbackup..."
    
    # Stoppen und Deaktivieren des Timers
    if [ -f "$timer_file" ]; then
        echo "Stoppe und deaktiviere den mdbackup-Timer..."
        if [ "$(id -u)" -eq 0 ]; then
            systemctl stop mdbackup.timer 2>/dev/null
            systemctl disable mdbackup.timer 2>/dev/null
        else
            sudo systemctl stop mdbackup.timer 2>/dev/null
            sudo systemctl disable mdbackup.timer 2>/dev/null
        fi
    fi
    
    # Backup-Daten
    read -p "Möchten Sie die vorhandenen Backup-Daten beibehalten? [J/n]: " keep_data
    keep_data=${keep_data:-J}
    
    if [[ ! "$keep_data" =~ ^[Jj] ]] && [ -d "$BACKUP_DIR" ]; then
        echo "Entferne Backup-Daten aus $BACKUP_DIR..."
        if [ "$(id -u)" -eq 0 ]; then
            rm -rf "$BACKUP_DIR"
        else
            sudo rm -rf "$BACKUP_DIR"
        fi
    else
        echo "Backup-Daten werden beibehalten."
    fi
    
    # Konfigurationsdatei
    read -p "Möchten Sie die Konfigurationsdatei entfernen? [j/N]: " remove_config
    remove_config=${remove_config:-N}
    
    if [[ "$remove_config" =~ ^[Jj] ]] && [ -f "$config_file" ]; then
        echo "Entferne Konfigurationsdatei $config_file..."
        if [ "$(id -u)" -eq 0 ]; then
            rm -f "$config_file"
        else
            sudo rm -f "$config_file"
        fi
    else
        echo "Konfigurationsdatei wird beibehalten."
    fi
    
    # Lösche Systemd-Dateien
    echo "Entferne systemd-Service-Dateien..."
    if [ "$(id -u)" -eq 0 ]; then
        rm -f "$service_file" 2>/dev/null
        rm -f "$timer_file" 2>/dev/null
    else
        sudo rm -f "$service_file" 2>/dev/null
        sudo rm -f "$timer_file" 2>/dev/null
    fi
    
    # Lösche das Skript und die Bibliotheken
    echo "Entferne Skript $script_path und Bibliotheken..."
    if [ "$(id -u)" -eq 0 ]; then
        rm -f "$script_path" 2>/dev/null
        rm -rf "$(dirname "$script_path")/lib" 2>/dev/null
    else
        sudo rm -f "$script_path" 2>/dev/null
        sudo rm -rf "$(dirname "$script_path")/lib" 2>/dev/null
    fi
    
    # Aktualisiere systemd
    echo "Aktualisiere systemd..."
    if [ "$(id -u)" -eq 0 ]; then
        systemctl daemon-reload
    else
        sudo systemctl daemon-reload
    fi
    
    echo "Deinstallation abgeschlossen."
    echo "Hinweis: Die Logdatei wurde nicht entfernt. Sie befindet sich unter $LOG_FILE."
}

# Funktion zur Installation
install() {
    # Starte mit einer umfassenden Überprüfung der Voraussetzungen
    check_prerequisites
    
    read -p "Do you want to install the mdbackup application? [Y/n]: " install_choice
    install_choice=${install_choice:-Y}

    if [[ "$install_choice" =~ ^[Yy] ]]; then
        install_script
    else
        echo "Installation aborted."
    fi
}

# Funktion zur Erstellung des Systemd-Services
create_service() {
    echo "Creating and configuring systemd service for mdbackup..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    
    local script_path="/usr/local/bin/mdbackup"
    local service_file="/etc/systemd/system/mdbackup.service"
    local timer_file="/etc/systemd/system/mdbackup.timer"
    
    # Prüfe, ob systemd verfügbar ist
    if ! command -v systemctl &> /dev/null; then
        echo "Error: systemd is not available on this system. Cannot create service." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        return 1
    fi
    
    # Service-Datei erstellen oder aktualisieren
    echo "Creating systemd service file at $service_file..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    
    cat > /tmp/mdbackup.service << EOF
[Unit]
Description=MariaDB/MySQL Automatic Backup Service
After=network.target mysql.service mariadb.service
Wants=mysql.service mariadb.service

[Service]
Type=oneshot
User=root
Group=root
ExecStart=$script_path backup
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
SuccessExitStatus=0
TimeoutStartSec=1200
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /tmp/mdbackup.service "$service_file"
    
    # Timer-Datei erstellen oder aktualisieren
    echo "Creating systemd timer file at $timer_file..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    
    # Lese die BACKUP_TIME aus der Konfiguration
    BACKUP_TIME="${BACKUP_TIME:-02:00}"
    
    cat > /tmp/mdbackup.timer << EOF
[Unit]
Description=Daily MariaDB/MySQL Backup Timer
After=network.target

[Timer]
OnCalendar=*-*-* $BACKUP_TIME
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

    sudo mv /tmp/mdbackup.timer "$timer_file"
    
    # systemd neu laden
    echo "Reloading systemd configuration..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    sudo systemctl daemon-reload
    
    # Timer aktivieren und starten
    echo "Enabling and starting mdbackup timer..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    sudo systemctl enable mdbackup.timer
    sudo systemctl start mdbackup.timer
    
    # Servicesstatus anzeigen
    echo "Service information:" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    echo "-------------------" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    echo "Next execution time:" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    sudo systemctl list-timers mdbackup.timer | grep mdbackup || echo "Timer not found."
    
    # Überprüfen, ob der Timer korrekt aktiviert wurde
    if sudo systemctl is-enabled --quiet mdbackup.timer; then
        echo "✅ mdbackup service and timer successfully created and activated." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        echo "The backup will run daily at $BACKUP_TIME." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    else
        echo "⚠️ Warning: Could not enable the timer service." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        return 1
    fi
    
    return 0
}

# Automatische Update-Funktion
update_script() {
    echo "Checking for updates..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    
    local update_available=false
    check_for_updates && update_available=true
    
    if [ "$update_available" = false ]; then
        echo "No updates available. Your script is already up to date." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        return
    fi
    
    # Sicherstellen, dass wir ein Skript downloaden können
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo "Error: Neither curl nor wget is available. Cannot perform update." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        return 1
    fi
    
    # Backup des aktuellen Skripts erstellen
    local script_path="$(realpath "$0")"
    local backup_path="${script_path}.backup-$(date +%Y%m%d%H%M%S)"
    
    echo "Creating backup of current script at $backup_path..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    cp "$script_path" "$backup_path" || { 
        echo "Failed to create backup. Aborting update." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        return 1
    }
    
    # Download des neuen Skripts
    echo "Downloading latest version..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    local temp_file=$(mktemp)
    
    if command -v curl &> /dev/null; then
        curl -s -o "$temp_file" "$REMOTE_SCRIPT_URL"
    else
        wget -q -O "$temp_file" "$REMOTE_SCRIPT_URL"
    fi
    
    # Überprüfen, ob der Download erfolgreich war
    if [ ! -s "$temp_file" ]; then
        echo "Failed to download the latest version. Restoring backup..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        mv "$backup_path" "$script_path"
        rm -f "$temp_file"
        return 1
    fi
    
    # Überprüfen, ob das heruntergeladene Skript ein gültiges Bash-Skript ist
    if ! head -n 1 "$temp_file" | grep -q "#!/bin/bash"; then
        echo "Downloaded file does not appear to be a valid bash script. Restoring backup..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        mv "$backup_path" "$script_path"
        rm -f "$temp_file"
        return 1
    fi
    
    # Vergleiche Versionsinformationen
    local new_version=$(grep "^VERSION=" "$temp_file" | head -n 1 | cut -d'"' -f2)
    echo "New version: $new_version" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    
    # Überschreibe das Skript mit der neuen Version
    echo "Installing new version..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    mv "$temp_file" "$script_path"
    chmod +x "$script_path"
    
    # Überprüfe, ob eine Installation vorhanden ist und aktualisiere sie
    local installed_path="/usr/local/bin/mdbackup"
    if [ -f "$installed_path" ]; then
        echo "Detected installed version. Updating system-wide installation..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        
        # Überprüfe, ob wir sudo-Rechte haben oder das Skript als Root ausgeführt wird
        if [ "$(id -u)" -eq 0 ] || command -v sudo &> /dev/null; then
            if [ "$(id -u)" -eq 0 ]; then
                cp "$script_path" "$installed_path"
                chmod +x "$installed_path"
            else
                sudo cp "$script_path" "$installed_path"
                sudo chmod +x "$installed_path"
            fi
            echo "System-wide installation updated." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
            
            # Neustart des Timers, falls vorhanden
            if [ -f "/etc/systemd/system/mdbackup.timer" ]; then
                echo "Restarting the mdbackup timer..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
                if [ "$(id -u)" -eq 0 ]; then
                    systemctl daemon-reload
                    systemctl restart mdbackup.timer
                else
                    sudo systemctl daemon-reload
                    sudo systemctl restart mdbackup.timer
                fi
                echo "Timer restarted." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
            fi
        else
            echo "Warning: Cannot update system-wide installation without sudo privileges." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        fi
    fi
    
    echo "Update completed successfully!" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    echo "New version: $new_version" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    echo "Previous version: $VERSION" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    echo "Backup saved at: $backup_path" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    echo "To revert to the previous version, run: mv \"$backup_path\" \"$script_path\"" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
}

# Funktion zur Überprüfung auf Updates
check_for_updates() {
    echo "Checking for updates..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    
    # Prüfen, ob curl oder wget verfügbar ist
    if command -v curl &> /dev/null; then
        local remote_version=$(curl -s "$REMOTE_VERSION_URL")
    elif command -v wget &> /dev/null; then
        local remote_version=$(wget -qO- "$REMOTE_VERSION_URL")
    else
        echo "Neither curl nor wget is installed. Cannot check for updates." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        return 1
    fi
    
    # Prüfung, ob die Remote-Version erfolgreich abgerufen wurde
    if [ -z "$remote_version" ]; then
        echo "Failed to retrieve remote version information." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        return 1
    fi
    
    echo "Current version: $VERSION" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    echo "Latest version: $remote_version" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    
    # Vergleichen der Versionen
    if [ "$remote_version" != "$VERSION" ]; then
        echo "Update available: $remote_version" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        return 0
    else
        echo "You have the latest version." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        return 1
    fi
}