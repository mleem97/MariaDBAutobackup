#!/bin/bash
#
# prerequisites.sh - Voraussetzungsprüfungen für MariaDBAutobackup
#

# Funktion zum Prüfen des verfügbaren Speicherplatzes
check_free_space() {
    # Mindestens erforderlicher freier Speicherplatz (in KB)
    local required_space=524288  # 512MB
    
    # Verfügbarer Speicherplatz auf dem Backup-Laufwerk
    local available_space=$(df -P "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        echo "Warning: Less than 512MB free space available on backup directory." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        echo "Available: $(( available_space / 1024 ))MB, Required: $(( required_space / 1024 ))MB" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        read -p "Continue anyway? [y/N]: " choice
        if [[ ! "$choice" =~ ^[Yy] ]]; then
            echo "Backup aborted due to insufficient disk space." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
            exit 1
        fi
    fi
    echo "Sufficient disk space available: $(( available_space / 1024 ))MB" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
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
    if [ "$1" == "install" ]; then
        dependencies+=("systemctl")
    fi
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Error: Required dependency '$dep' is not installed. Please install it first."
            exit 1
        fi
    done
}

# Funktion zur Überprüfung und Installation von Abhängigkeiten
check_and_install_dependencies() {
    local dependencies=("mysqldump" "gzip" "gunzip")
    if [ "$ENCRYPT_BACKUPS" == "yes" ]; then
        dependencies+=("gpg")
    fi
    local missing_dependencies=()
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_dependencies+=("$dep")
        fi
    done

    if [ ${#missing_dependencies[@]} -eq 0 ]; then
        echo "All necessary dependencies are already installed."
        return
    fi

    echo "The following dependencies are missing: ${missing_dependencies[*]}"
    read -p "Do you want to install them now? [Y/n]: " install_choice
    install_choice=${install_choice:-Y}

    if [[ "$install_choice" =~ ^[Yy] ]]; then
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

# Erweiterte Funktion zur umfassenden Prüfung aller Voraussetzungen
check_prerequisites() {
    echo "Performing comprehensive prerequisite check..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    
    # 1. Prüfung der MariaDB/MySQL-Installation
    echo "Checking MySQL/MariaDB installation..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    if ! command -v mysql &> /dev/null; then
        echo "MySQL/MariaDB is not installed." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        read -p "Would you like to install MySQL/MariaDB now? [y/N]: " install_db
        if [[ "$install_db" =~ ^[Yy] ]]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y mariadb-server
            elif command -v yum &> /dev/null; then
                sudo yum install -y mariadb-server
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y mariadb-server
            else
                handle_error "Unable to install MariaDB automatically. Please install it manually."
            fi
            # Starte MariaDB Service
            sudo systemctl enable mariadb
            sudo systemctl start mariadb
            echo "MariaDB installed and started." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        else
            handle_error "MySQL/MariaDB is required but not installed. Please install it first."
        fi
    fi
    echo "✅ MySQL/MariaDB is installed." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    
    # 2. Prüfung der Abhängigkeiten
    echo "Checking required dependencies..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    local dependencies=("mysqldump" "gzip" "find" "date")
    
    # Abhängigkeiten basierend auf Konfiguration hinzufügen
    if [ "$ENCRYPT_BACKUPS" == "yes" ]; then
        dependencies+=("gpg")
    fi
    if [ "$COMPRESSION_ALGORITHM" == "bzip2" ]; then
        dependencies+=("bzip2")
    elif [ "$COMPRESSION_ALGORITHM" == "xz" ]; then
        dependencies+=("xz")
    fi
    if [ -n "$REMOTE_RSYNC_TARGET" ]; then
        dependencies+=("rsync")
    fi
    
    # Prüfung aller benötigten Abhängigkeiten
    local missing_deps=()
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Missing dependencies: ${missing_deps[*]}" | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        read -p "Do you want to attempt to install these dependencies? [y/N]: " install_choice
        if [[ "$install_choice" =~ ^[Yy] ]]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y "${missing_deps[@]}"
            elif command -v yum &> /dev/null; then
                sudo yum install -y "${missing_deps[@]}"
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y "${missing_deps[@]}"
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm "${missing_deps[@]}"
            else
                handle_error "Unable to install dependencies automatically. Please install them manually: ${missing_deps[*]}"
            fi
            
            # Überprüfe, ob die Installation erfolgreich war
            local still_missing=()
            for dep in "${missing_deps[@]}"; do
                if ! command -v "$dep" &> /dev/null; then
                    still_missing+=("$dep")
                fi
            done
            
            if [ ${#still_missing[@]} -gt 0 ]; then
                handle_error "Failed to install some dependencies: ${still_missing[*]}"
            fi
        else
            handle_error "Please install the required dependencies first: ${missing_deps[*]}"
        fi
    fi
    echo "✅ All required dependencies are installed." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    
    # 3. Überprüfung der Konfiguration
    echo "Checking configuration file..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    if [ ! -f "$CONFIG_FILE" ] && [ ! -f "$LOCAL_CONFIG_FILE" ]; then
        echo "Configuration file not found. Setting up initial configuration..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        read -p "Would you like to configure the application now? [Y/n]: " configure_now
        configure_now=${configure_now:-Y}
        if [[ "$configure_now" =~ ^[Yy] ]]; then
            configure
        else
            echo "Using default configuration values." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        fi
    else
        echo "✅ Configuration file exists." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    fi
    
    # 4. Teste Datenbankverbindung
    echo "Testing database connection..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
    if ! mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
        echo "Cannot connect to the database." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
        
        if [ "$DATABASE_HOST" == "localhost" ]; then
            echo "Checking if MariaDB service is running..." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
            if command -v systemctl &> /dev/null && ! systemctl is-active --quiet mariadb && ! systemctl is-active --quiet mysql; then
                echo "MariaDB/MySQL service is not running." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
                read -p "Would you like to start it now? [Y/n]: " start_db
                start_db=${start_db:-Y}
                if [[ "$start_db" =~ ^[Yy] ]]; then
                    if systemctl list-unit-files | grep -q mariadb; then
                        sudo systemctl start mariadb
                    elif systemctl list-unit-files | grep -q mysql; then
                        sudo systemctl start mysql
                    else
                        handle_error "Could not determine which database service to start."
                    fi
                    echo "Database service started." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
                    
                    # Erneut versuchen, die Verbindung herzustellen
                    if ! mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
                        echo "Still cannot connect to the database." | tee -a "${LOG_FILE:-$LOG_DIR/mdbackup.log}"
                        read -p "Would you like to update database credentials? [Y/n]: " update_creds
                        update_creds=${update_creds:-Y}
                        if [[ "$update_creds" =~ ^[Yy] ]]; then
                            read -p "Database host [localhost]: " new_host
                            DATABASE_HOST=${new_host:-localhost}
                            read -p "Database user [root]: " new_user
                            DATABASE_USER=${new_user:-root}
                            read -p "Database password: " new_pass
                            DATABASE_PASSWORD="$new_pass"
                            
                            # Konfigurationsdatei aktualisieren
                            if [ -f "$CONFIG_FILE" ]; then
                                sed -i "s/DATABASE_HOST=.*/DATABASE_HOST=\"$DATABASE_HOST\"/" "$CONFIG_FILE"
                                sed -i "s/DATABASE_USER=.*/DATABASE_USER=\"$DATABASE_USER\"/" "$CONFIG_FILE"
                                sed -i "s/DATABASE_PASSWORD=.*/DATABASE_PASSWORD=\"$DATABASE_PASSWORD\"/" "$CONFIG_FILE"
                            elif [ -f "$LOCAL_CONFIG_FILE" ]; then
                                sed -i "s/DATABASE_HOST=.*/DATABASE_HOST=\"$DATABASE_HOST\"/" "$LOCAL_CONFIG_FILE"
                                sed -i "s/DATABASE_USER=.*/DATABASE_USER=\"$DATABASE_USER\"/" "$LOCAL_CONFIG_FILE"
                                sed -i "s/DATABASE_PASSWORD=.*/DATABASE_PASSWORD=\"$DATABASE_PASSWORD\"/" "$LOCAL_CONFIG_FILE"
                            else
                                # Erstelle eine neue Konfigurationsdatei wenn nötig
                                configure
                            fi
                            
                            # Erneut versuchen, die Verbindung herzustellen
                            if ! mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
                                handle_error "Still cannot connect to the database. Please check your credentials and ensure the database server is running."
                            fi
                        else
                            handle_error "Cannot proceed without a working database connection."
                        fi
                    fi
                else
                    handle_error "Cannot proceed with a stopped database service."
                fi
            else
                read -p "Would you like to update database credentials? [Y/n]: " update_creds
                update_creds=${update_creds:-Y}
                if [[ "$update_creds" =~ ^[Yy] ]]; then
                    # Ähnlicher Code wie oben zur Aktualisierung der Anmeldedaten
                    read -p "Database host [localhost]: " new_host
                    DATABASE_HOST=${new_host:-localhost}
                    read -p "Database user [root]: " new_user
                    DATABASE_USER=${new_user:-root}
                    read -p "Database password: " new_pass
                    DATABASE_PASSWORD="$new_pass"
                    
                    # Konfigurationsdatei aktualisieren
                    # ... (wie oben)
                    if [ -f "$CONFIG_FILE" ]; then
                        sed -i "s/DATABASE_HOST=.*/DATABASE_HOST=\"$DATABASE_HOST\"/" "$CONFIG_FILE"
                        sed -i "s/DATABASE_USER=.*/DATABASE_USER=\"$DATABASE_USER\"/" "$CONFIG_FILE"
                        sed -i "s/DATABASE_PASSWORD=.*/DATABASE_PASSWORD=\"$DATABASE_PASSWORD\"/" "$CONFIG_FILE"
                    elif [ -f "$LOCAL_CONFIG_FILE" ]; then
                        sed -i "s/DATABASE_HOST=.*/DATABASE_HOST=\"$DATABASE_HOST\"/" "$LOCAL_CONFIG_FILE"
                        sed -i "s/DATABASE_USER=.*/DATABASE_USER=\"$DATABASE_USER\"/" "$LOCAL_CONFIG_FILE"
                        sed -i "s/DATABASE_PASSWORD=.*/DATABASE_PASSWORD=\"$DATABASE_PASSWORD\"/" "$LOCAL_CONFIG_FILE"
                    else
                        configure
                    fi
                    
                    # Erneut versuchen
                    if ! mysql -h "$DATABASE_HOST" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
                        handle_error "Still cannot connect to the database. Please check your credentials and ensure the database server is running."
                    fi
                else
                    handle_error "Cannot proceed without a working database connection."
                fi
            fi
        fi
    fi
    echo "✅ Database connection successful." | tee -a "$LOG_FILE"
    
    # 5. Prüfung des Backup-Verzeichnisses
    echo "Checking backup directory..." | tee -a "$LOG_FILE"
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Backup directory does not exist. Creating it..." | tee -a "$LOG_FILE"
        mkdir -p "$BACKUP_DIR" || handle_error "Failed to create backup directory: $BACKUP_DIR"
    fi
    # Teste Schreibrechte im Backup-Verzeichnis
    if [ ! -w "$BACKUP_DIR" ]; then
        echo "No write permission to backup directory. Attempting to fix permissions..." | tee -a "$LOG_FILE"
        sudo chown -R $(whoami): "$BACKUP_DIR" || handle_error "Failed to set write permissions on backup directory: $BACKUP_DIR"
    fi
    echo "✅ Backup directory is writable." | tee -a "$LOG_FILE"
    
    # 6. Überprüfung des verfügbaren Speicherplatzes
    echo "Checking available disk space..." | tee -a "$LOG_FILE"
    local available_space=$(df -P "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    local min_space=524288  # 512MB in KB
    if [ "$available_space" -lt "$min_space" ]; then
        echo "Warning: Less than 512MB of free space available in backup directory." | tee -a "$LOG_FILE"
        read -p "Continue anyway? [y/N]: " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy] ]]; then
            exit 1
        fi
    fi
    echo "✅ Sufficient disk space available: $(( available_space / 1024 )) MB" | tee -a "$LOG_FILE"
    
    # 7. Prüfung der Remote-Backup-Konfiguration (falls aktiviert)
    if [ "$REMOTE_BACKUP_ENABLED" == "yes" ]; then
        echo "Checking remote backup configuration..." | tee -a "$LOG_FILE"
        if [ -n "$REMOTE_NFS_MOUNT" ]; then
            if ! command -v mount &> /dev/null; then
                handle_error "The 'mount' command is required for NFS backup but is not available."
            fi
            echo "✅ NFS mount prerequisites satisfied." | tee -a "$LOG_FILE"
        elif [ -n "$REMOTE_RSYNC_TARGET" ]; then
            if ! command -v rsync &> /dev/null; then
                handle_error "The 'rsync' command is required for remote backup but is not available."
            fi
            echo "✅ rsync prerequisites satisfied." | tee -a "$LOG_FILE"
        elif [ -n "$REMOTE_CLOUD_CLI" ]; then
            if ! command -v "$REMOTE_CLOUD_CLI" &> /dev/null; then
                handle_error "The '$REMOTE_CLOUD_CLI' command is required for cloud backup but is not available."
            fi
            echo "✅ Cloud CLI prerequisites satisfied." | tee -a "$LOG_FILE"
        else
            echo "Warning: Remote backup is enabled but no valid remote target is configured." | tee -a "$LOG_FILE"
        fi
    fi
    
    echo "All prerequisites checked and satisfied." | tee -a "$LOG_FILE"
}

# Funktion zur SSH-Tunnel Verbindung zur DB
connect_to_remote_db() {
    echo "Testing connection to remote database at $DATABASE_HOST..." | tee -a "$LOG_FILE"
    
    # Prüfen, ob ein SSH-Tunnel benötigt wird
    local need_ssh=false
    if [[ "$DATABASE_HOST" != "localhost" && "$DATABASE_HOST" != "127.0.0.1" ]]; then
        read -p "Do you need an SSH tunnel to connect to $DATABASE_HOST? [y/N]: " use_ssh
        if [[ "$use_ssh" =~ ^[Yy] ]]; then
            need_ssh=true
            # Prüfen, ob die SSH-Einstellungen konfiguriert sind
            if [ -z "$SSH_USER" ] || [ -z "$SSH_HOST" ]; then
                read -p "SSH username for database server: " SSH_USER
                read -p "SSH hostname for database server: " SSH_HOST
                read -p "SSH port [22]: " SSH_PORT
                SSH_PORT=${SSH_PORT:-22}
                
                # SSH-Einstellungen in die Konfiguration speichern
                if [ -f "$CONFIG_FILE" ]; then
                    echo "SSH_USER=\"$SSH_USER\"" >> "$CONFIG_FILE"
                    echo "SSH_HOST=\"$SSH_HOST\"" >> "$CONFIG_FILE"
                    echo "SSH_PORT=\"$SSH_PORT\"" >> "$CONFIG_FILE"
                elif [ -f "$LOCAL_CONFIG_FILE" ]; then
                    echo "SSH_USER=\"$SSH_USER\"" >> "$LOCAL_CONFIG_FILE"
                    echo "SSH_HOST=\"$SSH_HOST\"" >> "$LOCAL_CONFIG_FILE"
                    echo "SSH_PORT=\"$SSH_PORT\"" >> "$LOCAL_CONFIG_FILE"
                fi
            fi
            
            # Prüfen, ob ssh verfügbar ist
            if ! command -v ssh &> /dev/null; then
                handle_error "SSH is required but not installed. Please install OpenSSH client."
            fi
            
            # Aufbau des SSH-Tunnels
            echo "Setting up SSH tunnel to $SSH_HOST..." | tee -a "$LOG_FILE"
            local tunnel_port=13306  # Temporärer Port für den Tunnel
            ssh -f -N -L $tunnel_port:localhost:3306 -p $SSH_PORT $SSH_USER@$SSH_HOST
            
            if [ $? -ne 0 ]; then
                handle_error "Failed to establish SSH tunnel. Check your SSH credentials."
            fi
            
            echo "SSH tunnel established on local port $tunnel_port" | tee -a "$LOG_FILE"
            # Temporär den Datenbank-Host auf den Tunnel umleiten
            ORIGINAL_DB_HOST="$DATABASE_HOST"
            DATABASE_HOST="127.0.0.1"
            TUNNEL_PORT="$tunnel_port"
        fi
    fi
    
    # Datenbankverbindung testen
    if mysql -h "$DATABASE_HOST" -P "${TUNNEL_PORT:-3306}" -u "$DATABASE_USER" $([[ -n "$DATABASE_PASSWORD" ]] && echo "-p$DATABASE_PASSWORD") -e "SELECT 1" &>/dev/null; then
        echo "✅ Successfully connected to database at $ORIGINAL_DB_HOST" | tee -a "$LOG_FILE"
        return 0
    else
        echo "❌ Failed to connect to database at $ORIGINAL_DB_HOST" | tee -a "$LOG_FILE"
        
        # Wenn ein SSH-Tunnel verwendet wurde, diesen wieder schließen
        if [ "$need_ssh" = true ]; then
            echo "Closing SSH tunnel..." | tee -a "$LOG_FILE"
            pkill -f "ssh -f -N -L $TUNNEL_PORT:localhost:3306"
            DATABASE_HOST="$ORIGINAL_DB_HOST"
            unset TUNNEL_PORT
        fi
        
        return 1
    fi
}