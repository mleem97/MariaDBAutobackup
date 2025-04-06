# SSH-Tunnel für Remote-Datenbanken

Diese Anleitung erklärt, wie Sie SSH-Tunneling verwenden können, um auf entfernte MariaDB/MySQL-Datenbanken zuzugreifen und diese zu sichern.

## Überblick

SSH-Tunneling bietet eine sichere Methode, um auf eine entfernte Datenbank zuzugreifen, ohne den Datenbankport direkt im Internet zu öffnen. MariaDBAutobackup unterstützt SSH-Tunneling, um Ihre Datenbanksicherungen sicher zu gestalten.

## Voraussetzungen

- SSH-Zugriff auf den Remote-Server, auf dem die Datenbank läuft
- SSH-Schlüsselauthentifizierung eingerichtet (empfohlen) oder Kennwort
- SSH-Client auf dem Server, auf dem MariaDBAutobackup läuft

## Konfiguration

### Manuelle Konfiguration

Fügen Sie die folgenden Einstellungen zu Ihrer `/etc/mdbackup.conf` Datei hinzu:

```bash
# SSH-Tunnel-Einstellungen
SSH_USER="ssh_benutzername"
SSH_HOST="ssh_hostname_oder_ip"
SSH_PORT="22"  # Standard-SSH-Port (ändern Sie, wenn nötig)
```

Ersetzen Sie:
- `ssh_benutzername` mit Ihrem SSH-Benutzernamen auf dem Remote-Server
- `ssh_hostname_oder_ip` mit dem Hostnamen oder der IP-Adresse des Remote-Servers
- `22` mit dem SSH-Port, falls er vom Standard abweicht

### Konfiguration während der Backup-Ausführung

Wenn Sie keine SSH-Tunnel-Einstellungen in Ihrer Konfigurationsdatei haben, wird MariaDBAutobackup Sie interaktiv danach fragen, wenn Sie versuchen, ein Backup von einer Remote-Datenbank zu erstellen:

```bash
mdbackup backup
# Wählen Sie einen Backup-Typ
# Wenn DATABASE_HOST nicht localhost ist, werden Sie gefragt:
Do you need an SSH tunnel to connect to your-db-host? [y/N]:
```

Wenn Sie "y" eingeben, werden Sie aufgefordert, die SSH-Verbindungsdetails einzugeben.

## Funktionsweise

Wenn Sie ein Backup für eine Remote-Datenbank mit SSH-Tunnel ausführen:

1. MariaDBAutobackup erstellt einen temporären SSH-Tunnel vom lokalen Port 13306 zum MySQL/MariaDB-Port (3306) auf dem Remote-Server
2. Der Backup-Prozess verbindet sich mit der Datenbank über den Tunnel (127.0.0.1:13306)
3. Nach Abschluss des Backups wird der SSH-Tunnel automatisch geschlossen

## Beispiel für die Nutzung

1. Konfigurieren Sie Ihre Datenbankverbindung für einen entfernten Host:

   ```
   DATABASE_HOST="db.example.com"
   DATABASE_USER="db_user"
   DATABASE_PASSWORD="db_password"
   ```

2. Führen Sie den Backup-Befehl aus:

   ```bash
   sudo mdbackup backup
   ```

3. Wenn Sie nach einem SSH-Tunnel gefragt werden, wählen Sie "ja" und geben Sie SSH-Verbindungsinformationen ein.

## Fehlerbehebung

### SSH-Tunnel kann nicht aufgebaut werden

Wenn der folgende Fehler auftritt:
```
Failed to establish SSH tunnel. Check your SSH credentials.
```

Überprüfen Sie:
- SSH-Benutzername und Host sind korrekt
- SSH-Port ist korrekt
- Sie haben die entsprechenden SSH-Zugangsberechtigungen
- Die SSH-Schlüsselauthentifizierung ist korrekt eingerichtet

### Datenbankverbindung über Tunnel schlägt fehl

Wenn der folgende Fehler auftritt:
```
Failed to connect to database at [your-db-host]
```

Überprüfen Sie:
- Die MySQL/MariaDB-Instanz läuft auf dem Remote-Server
- Der Datenbankbenutzer hat die Berechtigung, sich über 'localhost' zu verbinden
- Firewall-Einstellungen blockieren nicht die lokale Verbindung
- MySQL/MariaDB ist für lokale Verbindungen konfiguriert

## Sicherheitstipps

- Verwenden Sie immer SSH-Schlüssel anstelle von Passwörtern, wenn möglich
- Beschränken Sie den SSH-Benutzer auf minimale Berechtigungen, die für Backups benötigt werden
- Verwenden Sie einen speziellen Datenbankbenutzer mit eingeschränkten Berechtigungen für Backups

## Nächste Schritte

Nachdem Sie SSH-Tunneling für Ihre Remote-Datenbanken konfiguriert haben, sollten Sie sich mit der [Verschlüsselung](Verschlüsselung.md) von Backups und [Remote-Backup-Speicheroptionen](Remote-Backups.md) vertraut machen.