# Installation von MariaDBAutobackup

Diese Anleitung führt Sie durch den Installationsprozess von MariaDBAutobackup.

## Voraussetzungen

- Linux-Betriebssystem (getestet auf Debian, Ubuntu, CentOS)
- Installierte MariaDB- oder MySQL-Datenbank
- Bash-Shell
- Root-Zugriff oder sudo-Berechtigung

## Installation über Git

1. Klonen Sie das Repository:

   ```bash
   git clone https://github.com/mleem97/MariaDBAutobackup.git
   ```

2. Wechseln Sie in das Verzeichnis:

   ```bash
   cd MariaDBAutobackup
   ```

3. Machen Sie das Skript ausführbar:

   ```bash
   chmod +x mdbackup.sh
   ```

4. Führen Sie den Installationsbefehl aus:

   ```bash
   sudo ./mdbackup.sh install
   ```

Während der Installation werden Sie nach den Konfigurationsdetails gefragt.

## Manuelle Installation

Alternativ können Sie das Skript auch manuell installieren:

1. Laden Sie die neueste Version herunter:

   ```bash
   curl -O https://raw.githubusercontent.com/mleem97/MariaDBAutobackup/main/mdbackup.sh
   ```

2. Machen Sie das Skript ausführbar:

   ```bash
   chmod +x mdbackup.sh
   ```

3. Kopieren Sie es in ein Verzeichnis im PATH:

   ```bash
   sudo cp mdbackup.sh /usr/local/bin/mdbackup
   ```

4. Erstellen Sie eine Konfigurationsdatei:

   ```bash
   sudo mdbackup configure
   ```

## Überprüfung der Installation

Um zu überprüfen, ob die Installation erfolgreich war:

```bash
mdbackup version
```

Dies sollte die aktuelle Version des Skripts anzeigen (z.B. 1.2.0).

## Systemd-Dienst einrichten

Nach der Installation wird automatisch ein systemd-Dienst und Timer eingerichtet. Sie können diesen Status überprüfen mit:

```bash
sudo systemctl status mdbackup.timer
```

Falls Sie den Dienst manuell einrichten möchten:

```bash
sudo mdbackup create-service
```

## Deinstallation

Um MariaDBAutobackup zu deinstallieren:

```bash
sudo mdbackup uninstall
```

Dieser Befehl entfernt das Skript, die Systemd-Dateien und optional die Konfigurationsdatei sowie Backup-Daten.

## Nächste Schritte

Nach erfolgreicher Installation sollten Sie mit der [Konfiguration](Konfiguration.md) fortfahren, um MariaDBAutobackup an Ihre Bedürfnisse anzupassen.