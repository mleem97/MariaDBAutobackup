# MariaDBAutobackup Debian-Paket

Diese Anleitung beschreibt, wie du das Debian-Paket für MariaDBAutobackup erstellst.

## Voraussetzungen

Um das Debian-Paket zu erstellen, benötigst du folgende Tools:

```bash
sudo apt-get install devscripts debhelper build-essential fakeroot lintian
```

## Paket erstellen

1. Klone das Repository:
   ```bash
   git clone https://github.com/mleem97/MariaDBAutobackup.git
   cd MariaDBAutobackup
   ```

2. Erstelle das Debian-Paket:
   ```bash
   debuild -us -uc
   ```

3. Nach erfolgreicher Erstellung findest du das Paket im übergeordneten Verzeichnis:
   ```bash
   cd ..
   ls mdbackup_*.deb
   ```

## Installation des Pakets

Das Paket kann manuell mit dpkg installiert werden:

```bash
sudo dpkg -i mdbackup_*.deb
sudo apt-get install -f  # Um fehlende Abhängigkeiten zu installieren
```

## Konfiguration

Nach der Installation:

1. Bearbeite die Konfigurationsdatei:
   ```bash
   sudo nano /etc/mdbackup.conf
   ```

2. Aktiviere und starte den Timer für regelmäßige Backups:
   ```bash
   sudo systemctl enable mdbackup.timer
   sudo systemctl start mdbackup.timer
   ```

3. Prüfe den Status des Timers:
   ```bash
   sudo systemctl status mdbackup.timer
   ```

## Manuelles Backup auslösen

Du kannst ein Backup manuell auslösen mit:

```bash
sudo mdbackup backup
```

## Dateien und Verzeichnisse

Nach der Installation findest du:

- Ausführbare Datei: `/usr/bin/mdbackup`
- Konfigurationsdatei: `/etc/mdbackup.conf`
- Logdatei: `/var/log/mdbackup.log`
- Backup-Verzeichnis: `/var/lib/mysql-backups`
- Systemd-Service: `/lib/systemd/system/mdbackup.service`
- Systemd-Timer: `/lib/systemd/system/mdbackup.timer`