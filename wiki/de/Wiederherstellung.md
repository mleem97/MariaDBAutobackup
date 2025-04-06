# Wiederherstellung von Backups

Diese Anleitung erklärt, wie Sie Datenbanken aus Backups wiederherstellen können, die mit MariaDBAutobackup erstellt wurden.

## Überblick

Die Wiederherstellung von Backups ist ein kritischer Prozess, der sorgfältig durchgeführt werden muss, um Datenverlust zu vermeiden. MariaDBAutobackup bietet einfache Befehle, um Datenbanken aus verschiedenen Backup-Typen wiederherzustellen.

## Voraussetzungen

- Ein funktionierendes Backup, das mit MariaDBAutobackup erstellt wurde
- Ausreichende Berechtigungen für die Wiederherstellung (normalerweise Root-Zugriff oder sudo-Berechtigung)
- Wenn das Backup verschlüsselt ist, benötigen Sie den entsprechenden GPG-Schlüssel

## Wiederherstellung mit dem interaktiven Befehl

Der einfachste Weg, ein Backup wiederherzustellen, ist der interaktive Wiederherstellungsbefehl:

```bash
sudo mdbackup restore
```

Dieser Befehl führt Sie durch die folgenden Schritte:

1. Anzeige der verfügbaren Backups
2. Auswahl des wiederherzustellenden Backups
3. Bestätigung der Wiederherstellung
4. Automatische Entschlüsselung (falls erforderlich)
5. Automatische Dekomprimierung (falls erforderlich)
6. Wiederherstellung der Datenbank(en)

## Wiederherstellung eines bestimmten Backups

Wenn Sie bereits wissen, welches Backup Sie wiederherstellen möchten:

```bash
sudo mdbackup restore /pfad/zum/backup/backup_file.sql.gz
```

## Wiederherstellung in eine bestimmte Datenbank

Wenn Sie ein Backup in eine bestimmte Datenbank wiederherstellen möchten:

```bash
sudo mdbackup restore --database=zieldatenbank /pfad/zum/backup/backup_file.sql.gz
```

Hinweis: Bei vollständigen Backups werden standardmäßig alle Datenbanken wiederhergestellt. Bei tabellen-spezifischen Backups wird die ursprüngliche Datenbank verwendet, es sei denn, Sie geben eine andere an.

## Wiederherstellung inkrementeller oder differentieller Backups

Bei inkrementellen oder differentiellen Backups müssen alle erforderlichen Backups in der Kette verfügbar sein:

1. Für differentielle Backups: Das letzte vollständige Backup und das differentielle Backup
2. Für inkrementelle Backups: Das letzte vollständige Backup und alle nachfolgenden inkrementellen Backups

MariaDBAutobackup erkennt automatisch Abhängigkeiten und führt die Wiederherstellung in der richtigen Reihenfolge durch.

## Manuelle Wiederherstellung (ohne den restore-Befehl)

In einigen Fällen möchten Sie möglicherweise ein Backup manuell wiederherstellen:

### 1. Entschlüsselung (falls verschlüsselt)

```bash
gpg --decrypt backup_file.sql.gz.gpg > backup_file.sql.gz
```

### 2. Dekomprimierung (falls komprimiert)

```bash
# Für gzip (Standardkomprimierung)
gunzip < backup_file.sql.gz > backup_file.sql

# Für bzip2
bunzip2 < backup_file.sql.bz2 > backup_file.sql

# Für xz
xz -d < backup_file.sql.xz > backup_file.sql
```

### 3. Wiederherstellung mit dem mysql-Befehl

```bash
# Vollständiges Backup
mysql -u root -p < backup_file.sql

# Für eine bestimmte Datenbank
mysql -u root -p database_name < backup_file.sql
```

## Wiederherstellung auf einem anderen Server

Um ein Backup auf einem anderen Server wiederherzustellen:

1. Kopieren Sie das Backup auf den Zielserver
2. Installieren Sie MariaDBAutobackup auf dem Zielserver oder verwenden Sie die manuelle Methode
3. Stellen Sie das Backup wie oben beschrieben wieder her

## Prüfung der Wiederherstellung

Nach der Wiederherstellung sollten Sie überprüfen, ob sie erfolgreich war:

```bash
# Verbindung zur Datenbank herstellen
mysql -u root -p

# Datenbanken auflisten
SHOW DATABASES;

# Eine bestimmte Datenbank auswählen
USE database_name;

# Tabellen auflisten
SHOW TABLES;

# Stichprobenprüfung der Daten
SELECT * FROM table_name LIMIT 10;
```

## Fehlerbehebung

### Berechtigungsprobleme

Wenn Sie Berechtigungsfehler erhalten:

```
ERROR 1044 (42000): Access denied for user 'username'@'localhost' to database 'database_name'
```

Stellen Sie sicher, dass der verwendete Benutzer ausreichende Berechtigungen hat:

```sql
GRANT ALL PRIVILEGES ON database_name.* TO 'username'@'localhost';
FLUSH PRIVILEGES;
```

### Fehler beim Entschlüsseln

Wenn Sie Probleme beim Entschlüsseln haben:

```
gpg: decryption failed: No secret key
```

Stellen Sie sicher, dass der richtige GPG-Schlüssel importiert ist:

```bash
gpg --import your_private_key.asc
```

### Datei nicht gefunden

Wenn MariaDBAutobackup das Backup nicht finden kann:

```
Error: Backup file not found at [path]
```

Überprüfen Sie den Pfad und die Berechtigungen:

```bash
ls -la /pfad/zum/backup/
```

## Bewährte Praktiken

- **Testen Sie regelmäßig die Wiederherstellung**: Führen Sie regelmäßig Wiederherstellungstests durch, um sicherzustellen, dass Ihre Backups funktionieren
- **Separate Umgebung**: Testen Sie Wiederherstellungen in einer separaten Umgebung, bevor Sie sie in der Produktion anwenden
- **Dokumentieren Sie**: Halten Sie Ihre Wiederherstellungsprozesse und -ergebnisse dokumentiert
- **Sichern Sie vor der Wiederherstellung**: Erstellen Sie ein Backup der aktuellen Daten, bevor Sie eine Wiederherstellung durchführen
- **Überprüfen Sie die Konsistenz**: Verwenden Sie den Befehl `mdbackup verify`, um die Integrität von Backups vor der Wiederherstellung zu überprüfen

## Nächste Schritte

Nachdem Sie sich mit der Wiederherstellung vertraut gemacht haben, sollten Sie sich mit der [Fehlerbehebung](Fehlerbehebung.md) und den [FAQs](FAQ.md) zu MariaDBAutobackup beschäftigen.