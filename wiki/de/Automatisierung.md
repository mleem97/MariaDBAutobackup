# Automatisierung von Backups

Diese Anleitung erklärt, wie Sie den Backup-Prozess mit MariaDBAutobackup automatisieren können.

## Überblick

Eine der Hauptfunktionen von MariaDBAutobackup ist die Möglichkeit, Datenbank-Backups zu automatisieren. Dies stellt sicher, dass Ihre Backups regelmäßig und zuverlässig ohne manuelle Eingriffe erstellt werden.

## Automatisierung mit systemd

MariaDBAutobackup nutzt systemd-Timer für die Automatisierung. Dies bietet gegenüber herkömmlichen Cron-Jobs mehrere Vorteile, darunter bessere Protokollierung, Abhängigkeitsverwaltung und Fehlerbehandlung.

### Standard-Installation

Während der Installation von MariaDBAutobackup wird automatisch ein systemd-Dienst und Timer eingerichtet. Sie können den Status überprüfen mit:

```bash
sudo systemctl status mdbackup.timer
sudo systemctl status mdbackup.service
```

### Manuelle Einrichtung des systemd-Dienstes

Wenn Sie den systemd-Dienst manuell einrichten möchten:

```bash
sudo mdbackup create-service
```

Dieser Befehl erstellt die Dateien:
- `/etc/systemd/system/mdbackup.service`
- `/etc/systemd/system/mdbackup.timer`

### Zeitplan anpassen

Der Backup-Zeitplan wird in der Konfigurationsdatei `/etc/mdbackup.conf` festgelegt:

```bash
# Zeitplan-Einstellungen
BACKUP_TIME="02:00"  # Tägliche Backups um 2:00 Uhr nachts (24-Stunden-Format)
```

Um diese Einstellung zu ändern:

1. Bearbeiten Sie die Konfigurationsdatei:
   ```bash
   sudo nano /etc/mdbackup.conf
   ```

2. Ändern Sie den Wert von `BACKUP_TIME`

3. Aktivieren Sie die Änderungen durch einen Neustart der Timer-Einheit:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart mdbackup.timer
   ```

### Erweiterte Zeitplanung

Für komplexere Zeitpläne können Sie die Timer-Datei direkt bearbeiten:

```bash
sudo nano /etc/systemd/system/mdbackup.timer
```

Beispiel für einen benutzerdefinierten Zeitplan (Backups am Montag und Donnerstag um 3:30 Uhr):

```ini
[Unit]
Description=MariaDBAutobackup Timer

[Timer]
OnCalendar=Mon,Thu *-*-* 03:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

Nach jeder Änderung:

```bash
sudo systemctl daemon-reload
sudo systemctl restart mdbackup.timer
```

## Automatisierung mit Pre- und Post-Backup-Hooks

MariaDBAutobackup unterstützt die Ausführung von benutzerdefinierten Skripten vor und nach dem Backup-Prozess.

### Pre-Backup-Skripte

Pre-Backup-Skripte werden ausgeführt, bevor das Backup beginnt. Diese können nützlich sein für:
- Vorbereitung der Datenbank (z.B. Schreiboperationen anhalten)
- Überprüfung von Voraussetzungen
- Benachrichtigungen senden

Konfiguration:

```bash
# In /etc/mdbackup.conf
PRE_BACKUP_SCRIPT="/pfad/zu/meinem/pre_backup_script.sh"
```

### Post-Backup-Skripte

Post-Backup-Skripte werden ausgeführt, nachdem das Backup abgeschlossen ist. Diese können nützlich sein für:
- Benachrichtigungen über den Backup-Status
- Zusätzliche Backup-Validierungen
- Aufräumarbeiten

Konfiguration:

```bash
# In /etc/mdbackup.conf
POST_BACKUP_SCRIPT="/pfad/zu/meinem/post_backup_script.sh"
```

### Beispiel für ein Post-Backup-Benachrichtigungsskript

Hier ist ein einfaches Beispiel für ein Skript, das nach einem Backup eine E-Mail-Benachrichtigung sendet:

```bash
#!/bin/bash
# /usr/local/bin/backup_notification.sh

BACKUP_STATUS=$1
BACKUP_FILE=$2
ADMIN_EMAIL="admin@example.com"

if [ "$BACKUP_STATUS" == "success" ]; then
    echo "MariaDB Backup erfolgreich: $BACKUP_FILE" | mail -s "Backup Erfolgreich" $ADMIN_EMAIL
else
    echo "MariaDB Backup fehlgeschlagen. Überprüfen Sie die Logs." | mail -s "⚠️ Backup FEHLGESCHLAGEN ⚠️" $ADMIN_EMAIL
fi
```

Machen Sie das Skript ausführbar:

```bash
sudo chmod +x /usr/local/bin/backup_notification.sh
```

Und fügen Sie es in Ihre Konfiguration ein:

```bash
POST_BACKUP_SCRIPT="/usr/local/bin/backup_notification.sh"
```

## Automatisierung mit verschiedenen Backup-Typen

Sie können eine Backup-Strategie mit verschiedenen Backup-Typen implementieren:

### Vollständige und inkrementelle Backups

Beispiel-Konfiguration für verschiedene Tage:

```bash
# Vollständiges Backup am Sonntag, inkrementelle an anderen Tagen
if [ $(date +%u) -eq 7 ]; then
  # Sonntag: Vollständiges Backup
  mdbackup backup --type=full
else
  # Andere Tage: Inkrementelles Backup
  mdbackup backup --type=incremental
fi
```

Speichern Sie dieses Skript als `/usr/local/bin/backup_strategy.sh` und machen Sie es ausführbar:

```bash
sudo chmod +x /usr/local/bin/backup_strategy.sh
```

Dann ändern Sie die systemd-Service-Datei, um dieses Skript auszuführen:

```bash
sudo nano /etc/systemd/system/mdbackup.service
```

Ändern Sie die `ExecStart`-Zeile:

```ini
ExecStart=/usr/local/bin/backup_strategy.sh
```

Und aktualisieren Sie systemd:

```bash
sudo systemctl daemon-reload
```

## Monitoring und Warnungen

### Log-Überwachung

Die Backup-Logs werden standardmäßig in `/var/log/mdbackup.log` gespeichert. Sie können Tools wie `logwatch` oder `fail2ban` konfigurieren, um diese zu überwachen und bei Fehlern zu warnen.

### Systemd-Integration

Sie können E-Mail-Benachrichtigungen für fehlgeschlagene systemd-Dienste einrichten:

1. Installieren Sie `postfix` und `mailx`:
   ```bash
   sudo apt-get install postfix mailx
   ```

2. Konfigurieren Sie systemd-E-Mail-Benachrichtigungen:
   ```bash
   sudo nano /etc/systemd/system/mdbackup.service
   ```

   Fügen Sie hinzu:
   ```ini
   [Service]
   # ...bestehende Konfiguration...
   OnFailure=status-email-admin@%n.service
   ```

3. Erstellen Sie den E-Mail-Dienst:
   ```bash
   sudo nano /etc/systemd/system/status-email-admin@.service
   ```

   Mit dem Inhalt:
   ```ini
   [Unit]
   Description=Status Email for %i Failure

   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/systemd-email admin@example.com %i
   ```

4. Erstellen Sie das E-Mail-Skript:
   ```bash
   sudo nano /usr/local/bin/systemd-email
   ```

   Mit dem Inhalt:
   ```bash
   #!/bin/bash
   
   to=$1
   unit=$2
   
   /usr/bin/systemctl status $unit | \
   /usr/bin/mail -s "Systemd-Dienst fehlgeschlagen: $unit" $to
   ```

5. Machen Sie das Skript ausführbar:
   ```bash
   sudo chmod +x /usr/local/bin/systemd-email
   ```

6. Aktualisieren Sie systemd:
   ```bash
   sudo systemctl daemon-reload
   ```

## Fehlerbehebung

### Timer startet nicht

Wenn der Timer nicht wie erwartet startet, überprüfen Sie:

```bash
# Timer-Status
sudo systemctl status mdbackup.timer

# Liste aller Timer
sudo systemctl list-timers

# Journal-Logs
sudo journalctl -u mdbackup.timer
sudo journalctl -u mdbackup.service
```

### Berechtigungsprobleme

Wenn Backups aufgrund von Berechtigungsproblemen fehlschlagen:

1. Stellen Sie sicher, dass der Benutzer, unter dem der Dienst läuft, Zugriff auf die Datenbank hat
2. Überprüfen Sie die Schreibberechtigungen im Backup-Verzeichnis:
   ```bash
   sudo ls -la /var/lib/mysql-backups
   ```

## Bewährte Praktiken

- **Testen Sie regelmäßig**: Führen Sie gelegentlich manuelle Tests durch, um sicherzustellen, dass die automatisierten Backups wie erwartet funktionieren
- **Überwachen Sie die Logs**: Richten Sie eine regelmäßige Überprüfung der Backup-Logs ein
- **Implementieren Sie Rotationsschemata**: Verwenden Sie die `BACKUP_RETENTION_DAYS`-Einstellung, um alte Backups zu entfernen
- **Validieren Sie Backups**: Richten Sie regelmäßige Test-Wiederherstellungen ein, um die Integrität der Backups zu überprüfen

## Nächste Schritte

Nach der Einrichtung der Automatisierung sollten Sie mehr über die [Wiederherstellung](Wiederherstellung.md) von Backups und die [Fehlerbehebung](Fehlerbehebung.md) bei häufigen Problemen erfahren.