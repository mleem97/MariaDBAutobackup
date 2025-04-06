# Remote-Backups

Diese Anleitung erklärt, wie Sie Remote-Backup-Optionen in MariaDBAutobackup konfigurieren und verwenden können.

## Überblick

MariaDBAutobackup unterstützt mehrere Methoden, um Ihre Backups an entfernte Speicherorte zu übertragen, was für eine effektive Disaster-Recovery-Strategie unerlässlich ist. Lokale Backups schützen Sie vor Datenbankausfällen, aber Remote-Backups schützen zusätzlich vor Hardware-Ausfällen, Standortproblemen und anderen Katastrophen.

## Unterstützte Remote-Speicheroptionen

MariaDBAutobackup unterstützt drei Haupttypen von Remote-Speicher:

1. **NFS (Network File System)**: Mounten eines Netzwerkspeichers und direkte Speicherung von Backups
2. **RSYNC**: Übertragung von Backups auf entfernte Server über das rsync-Protokoll
3. **Cloud-Speicher**: Upload von Backups zu Cloud-Diensten wie AWS S3, Google Cloud Storage oder anderen

## Konfiguration der Remote-Backup-Funktionen

Um Remote-Backups zu aktivieren, müssen Sie die Konfigurationsdatei `/etc/mdbackup.conf` bearbeiten oder den interaktiven Konfigurationsbefehl verwenden.

### Aktivierung der Remote-Backup-Funktion

Setzen Sie in der Konfigurationsdatei:

```bash
REMOTE_BACKUP_ENABLED="yes"
```

### NFS-Konfiguration

Um ein NFS-Share als Remote-Backup-Speicher zu verwenden:

```bash
REMOTE_NFS_MOUNT="/mnt/backups"  # Pfad, an dem das NFS-Share gemountet ist
```

Stellen Sie sicher, dass das NFS-Share korrekt in `/etc/fstab` eingerichtet ist oder mounten Sie es manuell vor der Ausführung von Backups:

```bash
sudo mount -t nfs nfs-server:/shared/backup /mnt/backups
```

### RSYNC-Konfiguration

Um Backups mit rsync auf einen entfernten Server zu übertragen:

```bash
REMOTE_RSYNC_TARGET="benutzer@host:/pfad/zu/backups"
```

Für eine passwortlose Authentifizierung sollten Sie SSH-Schlüssel einrichten:

```bash
# SSH-Schlüssel generieren (falls noch nicht vorhanden)
ssh-keygen -t rsa -b 4096

# Schlüssel auf den Zielserver kopieren
ssh-copy-id benutzer@host
```

### Cloud-Speicher-Konfiguration

Für Cloud-Speicher müssen Sie das entsprechende CLI-Tool installieren und konfigurieren:

```bash
REMOTE_CLOUD_CLI="aws"           # aws, gsutil (für Google Cloud), rclone, etc.
REMOTE_CLOUD_BUCKET="s3://my-backup-bucket/mysql"  # Cloud-Speicherziel
```

#### AWS S3 Beispiel

1. Installieren Sie die AWS CLI:
   ```bash
   sudo apt-get install awscli  # Debian/Ubuntu
   ```

2. Konfigurieren Sie die AWS-Anmeldeinformationen:
   ```bash
   aws configure
   ```

3. Setzen Sie die MariaDBAutobackup-Konfiguration:
   ```bash
   REMOTE_CLOUD_CLI="aws"
   REMOTE_CLOUD_BUCKET="s3://my-backup-bucket/mysql"
   ```

#### Google Cloud Storage Beispiel

1. Installieren Sie die Google Cloud SDK:
   ```bash
   # Debian/Ubuntu
   echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
   curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
   sudo apt-get update && sudo apt-get install google-cloud-sdk
   ```

2. Initialisieren Sie das SDK:
   ```bash
   gcloud init
   ```

3. Setzen Sie die MariaDBAutobackup-Konfiguration:
   ```bash
   REMOTE_CLOUD_CLI="gsutil"
   REMOTE_CLOUD_BUCKET="gs://my-backup-bucket/mysql"
   ```

## Überprüfung der Remote-Backup-Konfiguration

Nach der Konfiguration können Sie einen Test durchführen:

```bash
sudo mdbackup backup
```

Überprüfen Sie das Log auf mögliche Fehler:

```bash
sudo tail -n 50 /var/log/mdbackup.log
```

## Funktionsweise des Remote-Backup-Prozesses

Wenn Remote-Backups aktiviert sind, führt MariaDBAutobackup die folgenden Schritte aus:

1. Das Datenbank-Backup wird lokal erstellt
2. Je nach Konfiguration wird das Backup komprimiert und/oder verschlüsselt
3. Das Backup wird zum Remote-Speicherort übertragen:
   - Bei NFS: Dateien werden direkt auf das gemountete Netzlaufwerk kopiert
   - Bei RSYNC: Dateien werden mit rsync auf den entfernten Server übertragen
   - Bei Cloud-Speicher: Dateien werden mit dem konfigurierten CLI-Tool hochgeladen
4. Der Erfolg oder Misserfolg wird protokolliert

## Automatisierung von Remote-Backups

Remote-Backups werden automatisch ausgeführt, wenn sie aktiviert sind und ein Backup über den systemd-Timer oder manuell gestartet wird.

## Fehlerbehebung

### NFS-Probleme

Wenn Backups nicht auf das NFS-Share geschrieben werden können:

```
Error: Failed to write backup to NFS mount [/mnt/backups]
```

Überprüfen Sie:
- Das NFS-Share ist korrekt gemountet: `mount | grep /mnt/backups`
- Berechtigungen auf dem NFS-Share: `ls -la /mnt/backups`
- Netzwerkverbindung zum NFS-Server: `ping nfs-server`

### RSYNC-Probleme

Wenn die rsync-Übertragung fehlschlägt:

```
Error: Failed to transfer backup via rsync
```

Überprüfen Sie:
- SSH-Verbindung zum Zielserver: `ssh benutzer@host`
- Berechtigungen im Zielverzeichnis
- SSH-Schlüssel-Authentifizierung ist korrekt eingerichtet

### Cloud-Speicher-Probleme

Wenn der Upload zum Cloud-Speicher fehlschlägt:

```
Error: Failed to upload backup to cloud storage
```

Überprüfen Sie:
- Das CLI-Tool ist korrekt installiert und konfiguriert
- Anmeldeinformationen für den Cloud-Dienst sind gültig
- Bucket/Container existiert und ist zugänglich
- Internetverbindung ist verfügbar

## Bewährte Praktiken

- **Verschlüsselung**: Aktivieren Sie die Verschlüsselung für Remote-Backups, insbesondere in der Cloud
- **Überprüfung**: Führen Sie regelmäßig Test-Wiederherstellungen durch, um zu bestätigen, dass die Remote-Backups funktionieren
- **Redundanz**: Verwenden Sie mehrere Remote-Speicherorte für kritische Datenbanken
- **Monitoring**: Überwachen Sie den Remote-Backup-Prozess und richten Sie Benachrichtigungen bei Fehlern ein

## Nächste Schritte

Nachdem Sie Remote-Backups konfiguriert haben, sollten Sie sich mit der [Wiederherstellung](Wiederherstellung.md) von Backups und der [Automatisierung](Automatisierung.md) des Backup-Prozesses vertraut machen.