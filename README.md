# MariaDBAutobackup

Ein Skript, das automatische Backups einer MariaDB/MySQL-Datenbank ermöglicht.

## Übersicht

MariaDBAutobackup ist ein Shell-Skript, das entwickelt wurde, um regelmäßige Backups einer MariaDB/MySQL-Datenbank zu automatisieren. Es erleichtert die Sicherung und Wiederherstellung von Datenbanken, um den Verlust wichtiger Daten zu verhindern. Es bietet erweiterte Funktionen wie Verschlüsselung, Bereinigung alter Backups, verschiedene Backup-Typen und Remote-Backup-Optionen.

## Inhalt

- [Installation](#installation)
- [Konfiguration](#konfiguration)
- [Verwendung](#verwendung)
- [Backup-Typen](#backup-typen)
- [Remote Backup-Optionen](#remote-backup-optionen)
- [Automatisierung](#automatisierung)
- [Erweiterte Funktionen](#erweiterte-funktionen)
- [Beitragende](#beitragende)
- [Lizenz](#lizenz)

## Installation

1. Klone dieses Repository auf deinen lokalen Rechner:

    ```sh
    git clone https://github.com/mleem97/MariaDBAutobackup.git
    ```

2. Navigiere in das Verzeichnis des geklonten Repositories:

    ```sh
    cd MariaDBAutobackup
    ```

3. Stelle sicher, dass das Skript ausführbar ist:

    ```sh
    chmod +x mdbackup.sh
    ```

4. Führe das Skript mit dem folgenden Befehl aus:

    ```sh
    sudo ./mdbackup.sh install
    ```

## Konfiguration

1. Öffne die Konfigurationsdatei `/etc/mdbackup.conf` (falls vorhanden) oder erstelle sie.
2. Passe die Konfigurationsvariablen an deine Umgebung an. Beispielsweise:

    ```sh
    # Datenbank-Einstellungen
    DATABASE_HOST="localhost"
    DATABASE_USER="root"
    DATABASE_PASSWORD=""

    # Backup-Einstellungen
    BACKUP_DIR="/var/lib/mysql-backups"
    LOG_FILE="/var/log/mdbackup.log"
    BACKUP_RETENTION_DAYS="7"

    # Komprimierungs-Einstellungen
    COMPRESSION_ALGORITHM="gzip"
    COMPRESSION_LEVEL="6"

    # Verschlüsselungs-Einstellungen
    ENCRYPT_BACKUPS="no"
    GPG_KEY_ID=""

    # Zeitplan-Einstellungen
    BACKUP_TIME="02:00"

    # Remote Backup-Einstellungen
    REMOTE_BACKUP_ENABLED="no"
    # NFS-Einstellungen
    REMOTE_NFS_MOUNT=""
    # RSYNC-Einstellungen
    REMOTE_RSYNC_TARGET=""
    # Cloud-Einstellungen
    REMOTE_CLOUD_CLI=""
    REMOTE_CLOUD_BUCKET=""
    
    # SSH Tunnel-Einstellungen (für Remote-Datenbanken)
    SSH_USER=""
    SSH_HOST=""
    SSH_PORT="22"
    ```

## Verwendung

Das Skript unterstützt die folgenden Befehle:

- **Backup erstellen**:
  ```sh
  mdbackup backup
  ```
  Erstellt ein Backup der MariaDB/MySQL-Datenbank. Du kannst zwischen verschiedenen Backup-Typen wählen oder spezifische Tabellen sichern.

- **Backup wiederherstellen**:
  ```sh
  mdbackup restore
  ```
  Stellt eine Datenbank aus einem vorhandenen Backup wieder her.

- **Konfiguration anzeigen/ändern**:
  ```sh
  mdbackup configure
  ```
  Konfiguriert die Einstellungen des Skripts.

- **Komprimierungseinstellungen konfigurieren**:
  ```sh
  mdbackup configure-compression
  ```
  Konfiguriert speziell die Komprimierungseinstellungen.

- **Service erstellen**:
  ```sh
  mdbackup create-service
  ```
  Erstellt einen systemd-Service und Timer für automatische Backups.

- **Skript aktualisieren**:
  ```sh
  mdbackup update
  ```
  Aktualisiert das Skript auf die neueste Version.

- **Version anzeigen**:
  ```sh
  mdbackup version
  ```
  Zeigt die aktuelle Version des Skripts an (aktuell 1.2.0).

- **Updates überprüfen**:
  ```sh
  mdbackup check-updates
  ```
  Überprüft, ob Updates für das Skript verfügbar sind.

- **Skript installieren**:
  ```sh
  mdbackup install
  ```
  Installiert das Skript und richtet einen Service ein.

- **Skript deinstallieren**:
  ```sh
  mdbackup uninstall
  ```
  Deinstalliert das Skript und entfernt den Service.

- **Backup-Integrität prüfen**:
  ```sh
  mdbackup verify
  ```
  Überprüft die Integrität eines Backups anhand von Checksummen.

- **Hilfe anzeigen**:
  ```sh
  mdbackup help
  ```
  Zeigt die verfügbaren Befehle und deren Beschreibung an.

## Backup-Typen

Das Skript unterstützt verschiedene Backup-Typen:

- **Vollständiges Backup**: Ein komplettes Backup aller Datenbanken.
- **Differentielles Backup**: Speichert nur die Änderungen seit dem letzten vollständigen Backup.
- **Inkrementelles Backup**: Speichert nur die Änderungen seit dem letzten Backup (egal welchen Typs).
- **Tabellen-spezifisches Backup**: Sichert nur ausgewählte Tabellen einer bestimmten Datenbank.

## Remote Backup-Optionen

Das Skript unterstützt die Übertragung von Backups zu entfernten Speicherorten:

- **NFS-Share**: Backups können auf ein NFS-Share kopiert werden.
- **RSYNC**: Backups können mit rsync auf entfernte Server übertragen werden.
- **Cloud-Speicher**: Backups können mithilfe eines Cloud-CLI-Tools auf Cloud-Speicher hochgeladen werden (z.B. AWS S3, Google Cloud Storage).

## Automatisierung

Nach der Installation wird ein systemd-Timer eingerichtet, der das Backup täglich zur konfigurierten Zeit ausführt:

```sh
# Zeigt den Status des Timers an
sudo systemctl status mdbackup.timer
```

## Erweiterte Funktionen

- **Abhängigkeitsprüfung und Installation**: Das Skript überprüft und installiert automatisch erforderliche Abhängigkeiten.
- **Verschlüsselung**: Backups können optional mit GPG verschlüsselt werden.
- **Bereinigung alter Backups**: Backups, die älter als die konfigurierte Anzahl von Tagen sind, werden automatisch gelöscht.
- **Testmodus**: Führt Befehle im Testmodus aus, ohne Änderungen vorzunehmen.
- **Pre- und Post-Backup-Hooks**: Ermöglicht die Ausführung von benutzerdefinierten Skripten vor und nach dem Backup-Prozess.
- **Fortschrittsanzeige**: Visualisiert den Backup-Fortschritt bei längeren Prozessen.
- **Automatische Updates**: Überprüft regelmäßig auf Updates des Skripts.
- **Konfigurationsprüfung**: Validiert die Konfigurationsdatei vor dem Ausführen von Backups.
- **Remote-Datenbankunterstützung**: Verbindet sich mit Remote-Datenbanken, optional über SSH-Tunnel.
- **Komprimierungsoptionen**: Unterstützt verschiedene Algorithmen (gzip, bzip2, xz) mit einstellbaren Komprimierungsleveln.
- **Integritätsprüfung**: Erstellt und überprüft Checksummen für alle Backup-Dateien.

## Hinweise
- Das Skript ist derzeit in Version 1.2.0.
- Bitte nutzt die **"Issues"** auf GitHub um Fehler zu melden oder Verbesserungsvorschläge einzureichen.

## Beitragende

[mleem97](https://github.com/mleem97)

## Lizenz

Dieses Projekt ist unter der GNU-GPL-Lizenz lizenziert. Siehe die LICENSE-Datei für Details.
