# Fehlerbehebung

Diese Anleitung hilft Ihnen bei der Lösung häufiger Probleme und Fehler, die bei der Verwendung von MariaDBAutobackup auftreten können.

## Häufige Backup-Probleme

### Backup kann nicht erstellt werden

**Problem**: Der Backup-Prozess schlägt mit einer Fehlermeldung fehl.

**Mögliche Ursachen und Lösungen**:

1. **Datenbankverbindungsprobleme**:
   ```
   Error: Failed to connect to database at [host]
   ```
   - Überprüfen Sie, ob die Datenbank läuft: `sudo systemctl status mariadb`
   - Stellen Sie sicher, dass die Anmeldeinformationen korrekt sind
   - Testen Sie die Verbindung manuell: `mysql -u [user] -p -h [host]`

2. **Berechtigungsprobleme**:
   ```
   Error: Permission denied when writing to [backup_dir]
   ```
   - Überprüfen Sie die Berechtigungen des Backup-Verzeichnisses: `ls -la [backup_dir]`
   - Ändern Sie den Besitzer oder die Berechtigungen: `sudo chown -R [user]:[group] [backup_dir]`
   - Oder führen Sie das Backup mit sudo aus: `sudo mdbackup backup`

3. **Nicht genügend Speicherplatz**:
   ```
   Error: No space left on device
   ```
   - Überprüfen Sie den verfügbaren Speicherplatz: `df -h`
   - Bereinigen Sie alte Backups: `sudo mdbackup cleanup`
   - Konfigurieren Sie eine kürzere Aufbewahrungsdauer: `BACKUP_RETENTION_DAYS="3"`

4. **Mysqldump-Fehler**:
   ```
   Error: mysqldump command failed with exit code [code]
   ```
   - Prüfen Sie, ob mysqldump installiert ist: `which mysqldump`
   - Überprüfen Sie die vollständige Fehlermeldung im Log: `sudo cat /var/log/mdbackup.log`

### Probleme mit inkrementellen/differentiellen Backups

**Problem**: Inkrementelle oder differentielle Backups schlagen fehl.

**Lösungen**:

1. **Kein vollständiges Backup als Basis**:
   - Erstellen Sie zunächst ein vollständiges Backup: `sudo mdbackup backup --type=full`

2. **Binärlogs nicht aktiviert**:
   - Aktivieren Sie Binärlogs in der MariaDB/MySQL-Konfiguration:
     ```
     # /etc/mysql/mariadb.conf.d/50-server.cnf oder /etc/my.cnf
     [mysqld]
     log-bin=mysql-bin
     binlog_format=ROW
     ```
   - Starten Sie die Datenbank neu: `sudo systemctl restart mariadb`

### Probleme mit verschlüsselten Backups

**Problem**: Die Verschlüsselung oder Entschlüsselung schlägt fehl.

**Lösungen**:

1. **GPG nicht gefunden**:
   - Installieren Sie GPG: `sudo apt-get install gnupg`

2. **GPG-Schlüssel nicht gefunden**:
   ```
   Error: No public key found for encryption
   ```
   - Überprüfen Sie den konfigurierten Schlüssel: `gpg --list-keys [key_id]`
   - Stellen Sie sicher, dass der richtige Schlüssel in der Konfiguration angegeben ist

3. **Entschlüsselung fehlgeschlagen**:
   ```
   gpg: decryption failed: No secret key
   ```
   - Importieren Sie den privaten Schlüssel: `gpg --import private_key.asc`

## Probleme mit Remote-Backups

### NFS-Mount-Probleme

**Problem**: Backups können nicht auf NFS gespeichert werden.

**Lösungen**:

1. **Mount fehlgeschlagen**:
   - Überprüfen Sie, ob das NFS-Share gemountet ist: `mount | grep [mount_point]`
   - Mounten Sie es manuell: `sudo mount -t nfs [server]:[share] [mount_point]`
   - Konfigurieren Sie den Mount in `/etc/fstab` für die automatische Einbindung

2. **Berechtigungsprobleme auf NFS**:
   - Überprüfen Sie die NFS-Export-Berechtigungen auf dem Server
   - Stellen Sie sicher, dass der NFS-Client die richtigen Berechtigungen hat

### RSYNC-Probleme

**Problem**: Die rsync-Übertragung schlägt fehl.

**Lösungen**:

1. **SSH-Verbindung fehlgeschlagen**:
   - Überprüfen Sie, ob SSH-Schlüssel korrekt eingerichtet sind
   - Testen Sie die SSH-Verbindung manuell: `ssh [user]@[host]`

2. **Zielverzeichnis nicht vorhanden oder keine Schreibberechtigung**:
   - Erstellen Sie das Zielverzeichnis: `ssh [user]@[host] "mkdir -p [directory]"`
   - Setzen Sie die richtigen Berechtigungen

### Cloud-Speicher-Probleme

**Problem**: Der Upload zu Cloud-Speicher schlägt fehl.

**Lösungen**:

1. **CLI-Tool nicht gefunden**:
   - Installieren Sie das entsprechende CLI-Tool:
     - AWS: `sudo apt-get install awscli`
     - Google Cloud: `sudo apt-get install google-cloud-sdk`

2. **Authentifizierungsprobleme**:
   - Konfigurieren Sie das CLI-Tool mit gültigen Anmeldeinformationen:
     - AWS: `aws configure`
     - Google Cloud: `gcloud auth login`

3. **Bucket/Container nicht gefunden**:
   - Überprüfen Sie, ob der Bucket existiert
   - Stellen Sie sicher, dass der richtige Pfad konfiguriert ist

## Probleme mit automatisierten Backups

### Systemd-Timer startet nicht

**Problem**: Automatisierte Backups werden nicht ausgeführt.

**Lösungen**:

1. **Timer nicht aktiviert**:
   - Überprüfen Sie den Status: `sudo systemctl status mdbackup.timer`
   - Aktivieren Sie den Timer: `sudo systemctl enable mdbackup.timer`
   - Starten Sie den Timer: `sudo systemctl start mdbackup.timer`

2. **Timer falsch konfiguriert**:
   - Überprüfen Sie die Timer-Datei: `sudo cat /etc/systemd/system/mdbackup.timer`
   - Passen Sie die Backup-Zeit in der Konfiguration an: `/etc/mdbackup.conf`
   - Laden Sie systemd neu: `sudo systemctl daemon-reload`

3. **Service fehlgeschlagen**:
   - Überprüfen Sie die Service-Logs: `sudo journalctl -u mdbackup.service`
   - Beheben Sie die Fehler basierend auf den Log-Meldungen

## Probleme bei der Wiederherstellung

### Wiederherstellung schlägt fehl

**Problem**: Die Wiederherstellung eines Backups schlägt fehl.

**Lösungen**:

1. **Backup-Datei beschädigt**:
   - Überprüfen Sie die Integrität des Backups: `sudo mdbackup verify [backup_file]`
   - Verwenden Sie ein älteres Backup, wenn verfügbar

2. **Dekompressionsfehler**:
   - Stellen Sie sicher, dass die entsprechenden Dekomprimierungstools installiert sind:
     - gzip: `sudo apt-get install gzip`
     - bzip2: `sudo apt-get install bzip2`
     - xz: `sudo apt-get install xz-utils`

3. **MySQL/MariaDB-Fehler während der Wiederherstellung**:
   - Überprüfen Sie die vollständige Fehlermeldung im Log: `sudo cat /var/log/mdbackup.log`
   - Typische Probleme können sein:
     - Syntax-Fehler im SQL-Dump
     - Konflikte mit vorhandenen Datenbanken/Tabellen
     - Inkompatible Datenbankversionen

## Lösung allgemeiner Probleme

### Abhängigkeitsprobleme

**Problem**: Fehlende Abhängigkeiten für MariaDBAutobackup.

**Lösungen**:

1. **Ausführen der automatischen Abhängigkeitsinstallation**:
   ```bash
   sudo mdbackup check-dependencies --install
   ```

2. **Manuelle Installation von Abhängigkeiten**:
   ```bash
   sudo apt-get update
   sudo apt-get install mariadb-client gzip bzip2 xz-utils gnupg rsync curl
   ```

### Probleme mit Logdateien

**Problem**: Die Log-Datei wächst zu groß oder ist nicht vorhanden.

**Lösungen**:

1. **Log-Rotation konfigurieren**:
   - Erstellen Sie eine logrotate-Konfiguration:
     ```bash
     sudo nano /etc/logrotate.d/mdbackup
     ```
     
     Mit dem Inhalt:
     ```
     /var/log/mdbackup.log {
         weekly
         rotate 4
         compress
         missingok
         notifempty
         create 0640 root root
     }
     ```

2. **Log-Datei nicht beschreibbar**:
   - Überprüfen und korrigieren Sie die Berechtigungen:
     ```bash
     sudo touch /var/log/mdbackup.log
     sudo chmod 640 /var/log/mdbackup.log
     sudo chown root:root /var/log/mdbackup.log
     ```

### Aktualisierungsprobleme

**Problem**: Probleme bei der Aktualisierung von MariaDBAutobackup.

**Lösungen**:

1. **Manuelle Aktualisierung**:
   ```bash
   cd /path/to/MariaDBAutobackup
   git pull
   sudo ./mdbackup.sh install
   ```

2. **Konfiguration nach der Aktualisierung wiederherstellen**:
   - Sichern Sie Ihre Konfiguration vor der Aktualisierung
   - Stellen Sie sicher, dass neue Konfigurationsoptionen hinzugefügt werden

## Diagnose-Tools

### Log-Analyse

Um die Logs auf Fehler zu überprüfen:

```bash
sudo grep "ERROR\|Error\|error" /var/log/mdbackup.log
```

### Überprüfung der Konfiguration

Validieren Sie Ihre Konfiguration:

```bash
sudo mdbackup validate-config
```

### Testmodus

Führen Sie Befehle im Testmodus aus, um Probleme zu diagnostizieren, ohne tatsächliche Änderungen vorzunehmen:

```bash
sudo mdbackup backup --dry-run
```

### Debug-Modus

Aktivieren Sie ausführlichere Logging für die Fehlersuche:

```bash
sudo DEBUG=1 mdbackup backup
```

## Support und Hilfe

Wenn Sie das Problem nicht lösen können:

1. Überprüfen Sie die [FAQ](FAQ.md) auf bekannte Probleme und Lösungen
2. Suchen Sie in den [GitHub Issues](https://github.com/mleem97/MariaDBAutobackup/issues) nach ähnlichen Problemen
3. Erstellen Sie ein neues Issue mit:
   - Genaue Fehlermeldung
   - Ausgabe des Befehls: `sudo mdbackup version`
   - Relevante Teile der Log-Datei
   - Details zu Ihrer Umgebung (Betriebssystem, MariaDB/MySQL-Version)
   - Durchgeführte Schritte zur Reproduktion des Problems