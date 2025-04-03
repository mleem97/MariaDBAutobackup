# MariaDBAutobackup

Ein Skript, das automatische Backups einer MariaDB-Live-Datenbank ermöglicht.

## Übersicht

MariaDBAutobackup ist ein Shell-Skript, das entwickelt wurde, um regelmäßige Backups einer MariaDB-Datenbank zu automatisieren. Es erleichtert die Sicherung und Wiederherstellung von Datenbanken, um den Verlust wichtiger Daten zu verhindern. Es bietet erweiterte Funktionen wie Verschlüsselung, Bereinigung alter Backups und Cron-Job-Integration.

## Inhalt

- [Installation](#installation)
- [Konfiguration](#konfiguration)
- [Verwendung](#verwendung)
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
    DEFAULT_BACKUP_DIR="/var/lib/mysql"
    LOG_FILE="/var/log/mdbackup.log"
    ```

## Verwendung

Das Skript unterstützt die folgenden Befehle:

- **Backup erstellen**:
  ```sh
  mdbackup backup
  ```
  Erstellt ein Backup der MariaDB-Datenbank. Du kannst wählen, ob alle Datenbanken oder nur eine spezifische gesichert werden sollen.

- **Backup wiederherstellen**:
  ```sh
  mdbackup restore
  ```
  Stellt eine Datenbank aus einem vorhandenen Backup wieder her.

- **Hilfe anzeigen**:
  ```sh
  mdbackup help
  ```
  Zeigt die verfügbaren Befehle und deren Beschreibung an.

## Automatisierung

Um regelmäßige Backups zu automatisieren, richte einen Cron-Job ein:

```sh
sudo mdbackup.sh setup_cron_job
```

Dies erstellt einen täglichen Cron-Job, der das Backup um 2:00 Uhr ausführt.

## Erweiterte Funktionen

- **Abhängigkeitsprüfung und Installation**: Das Skript überprüft und installiert automatisch erforderliche Abhängigkeiten wie `mysqldump`, `gzip` und `gunzip`.
- **Verschlüsselung**: Backups können optional mit GPG verschlüsselt werden.
- **Bereinigung alter Backups**: Backups, die älter als 30 Tage sind, werden automatisch gelöscht.
- **Testmodus**: Führt Befehle im Testmodus aus, ohne Änderungen vorzunehmen.
- **Remote-Installation**: Unterstützt die Installation auf entfernten Geräten über SSH.

## Hinweise
- Das Script wurde stand 03.04.25 noch nicht getestet. Bitte nutzt die **"Issues"** um Fehler zu melden. 

## Beitragende

[mleem97](https://github.com/mleem97)

## Lizenz

Dieses Projekt ist unter der GNU-GPL-Lizenz lizenziert. Siehe die LICENSE-Datei für Details.
