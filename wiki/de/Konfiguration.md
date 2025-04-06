# Konfiguration von MariaDBAutobackup

Diese Anleitung beschreibt die verschiedenen Konfigurationsoptionen von MariaDBAutobackup.

## Konfigurationsdatei

Die Hauptkonfigurationsdatei befindet sich unter `/etc/mdbackup.conf`. Diese Datei wird während der Installation erstellt oder kann manuell mit dem folgenden Befehl erstellt werden:

```bash
sudo mdbackup configure
```

## Konfigurationsoptionen

### Datenbank-Einstellungen

```bash
# Datenbank-Einstellungen
DATABASE_HOST="localhost"       # Hostname oder IP der MariaDB/MySQL-Datenbank
DATABASE_PORT="3306"            # Port der Datenbank
DATABASE_USER="root"            # Benutzername für die Datenbankverbindung
DATABASE_PASSWORD="password"    # Passwort für die Datenbankverbindung
```

### Backup-Einstellungen

```bash
# Backup-Einstellungen
BACKUP_DIR="/var/lib/mysql-backups"  # Verzeichnis, in dem Backups gespeichert werden
LOG_FILE="/var/log/mdbackup.log"     # Pfad zur Log-Datei
BACKUP_RETENTION_DAYS="7"            # Anzahl der Tage, für die Backups aufbewahrt werden
```

### Komprimierungs-Einstellungen

```bash
# Komprimierungs-Einstellungen
COMPRESSION_ALGORITHM="gzip"    # Mögliche Werte: "gzip", "bzip2", "xz", "none"
COMPRESSION_LEVEL="6"           # Komprimierungsstufe (1-9, wobei 9 die stärkste Komprimierung ist)
```

### Verschlüsselungs-Einstellungen

```bash
# Verschlüsselungs-Einstellungen
ENCRYPT_BACKUPS="no"            # Aktivieren Sie die Verschlüsselung mit "yes"
GPG_KEY_ID=""                   # GPG-Schlüssel-ID für die Verschlüsselung
```

### Zeitplan-Einstellungen

```bash
# Zeitplan-Einstellungen
BACKUP_TIME="02:00"             # Uhrzeit für geplante Backups (24-Stunden-Format)
```

### Remote Backup-Einstellungen

```bash
# Remote Backup-Einstellungen
REMOTE_BACKUP_ENABLED="no"      # Aktivieren Sie Remote-Backups mit "yes"

# NFS-Einstellungen (mindestens eine Remote-Option aktivieren)
REMOTE_NFS_MOUNT=""             # NFS-Mount-Punkt

# RSYNC-Einstellungen
REMOTE_RSYNC_TARGET=""          # Rsync-Ziel im Format "benutzer@host:/pfad"

# Cloud-Einstellungen
REMOTE_CLOUD_CLI=""             # Cloud-CLI-Tool (z.B. "aws", "gsutil", "rclone")
REMOTE_CLOUD_BUCKET=""          # Cloud-Bucket oder Ziel
```

### SSH Tunnel-Einstellungen

```bash
# SSH Tunnel-Einstellungen (für Remote-Datenbanken)
SSH_USER=""                     # SSH-Benutzername
SSH_HOST=""                     # SSH-Host
SSH_PORT="22"                   # SSH-Port
```

### Pre- und Post-Backup-Hooks

```bash
# Pre- und Post-Backup-Hooks
PRE_BACKUP_SCRIPT=""            # Pfad zu einem Skript, das vor dem Backup ausgeführt wird
POST_BACKUP_SCRIPT=""           # Pfad zu einem Skript, das nach dem Backup ausgeführt wird
```

## Konfiguration über die Befehlszeile

MariaDBAutobackup bietet verschiedene Befehle, um die Konfiguration zu verwalten:

### Allgemeine Konfiguration

```bash
sudo mdbackup configure
```

Dieser Befehl führt Sie interaktiv durch die wichtigsten Konfigurationsoptionen.

### Spezifische Komprimierungseinstellungen

```bash
sudo mdbackup configure-compression
```

Dieser Befehl ermöglicht es Ihnen, den Komprimierungsalgorithmus und die Komprimierungsstufe anzupassen.

## Konfigurationsvalidierung

MariaDBAutobackup überprüft Ihre Konfiguration vor jedem Backup auf Gültigkeit. Wenn Probleme gefunden werden, erhalten Sie entsprechende Warnungen oder Fehlermeldungen.

## Umgebungsvariablen

Zusätzlich zur Konfigurationsdatei können Sie temporäre Änderungen über Umgebungsvariablen vornehmen:

```bash
DATABASE_PASSWORD="mein_passwort" mdbackup backup
```

Diese Methode ist nützlich für Skripte oder einmalige Änderungen, ohne die Konfigurationsdatei zu bearbeiten.

## Beispielkonfiguration

Hier ist eine vollständige Beispielkonfiguration für ein tägliches Backup mit Komprimierung und Fernübertragung zu einem NFS-Share:

```bash
# Datenbank-Einstellungen
DATABASE_HOST="localhost"
DATABASE_PORT="3306"
DATABASE_USER="backup_user"
DATABASE_PASSWORD="sicheres_passwort"

# Backup-Einstellungen
BACKUP_DIR="/var/lib/mysql-backups"
LOG_FILE="/var/log/mdbackup.log"
BACKUP_RETENTION_DAYS="14"

# Komprimierungs-Einstellungen
COMPRESSION_ALGORITHM="gzip"
COMPRESSION_LEVEL="6"

# Verschlüsselungs-Einstellungen
ENCRYPT_BACKUPS="no"
GPG_KEY_ID=""

# Zeitplan-Einstellungen
BACKUP_TIME="02:00"

# Remote Backup-Einstellungen
REMOTE_BACKUP_ENABLED="yes"
REMOTE_NFS_MOUNT="/mnt/backups"
```

## Sicherheitshinweise

- Schützen Sie Ihre Konfigurationsdatei, da sie sensible Informationen wie Datenbankpasswörter enthält
- Verwenden Sie einen dedizierten Datenbankbenutzer mit minimalen Berechtigungen für Backups
- Überprüfen Sie die Berechtigungen der Konfigurationsdatei: `sudo chmod 600 /etc/mdbackup.conf`

## Nächste Schritte

Nachdem Sie MariaDBAutobackup konfiguriert haben, können Sie mehr über die [Backup-Typen](Backup-Typen.md) und die [Automatisierung](Automatisierung.md) von Backups erfahren.