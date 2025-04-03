# MariaDBAutobackup

Ein Skript, das automatische Backups einer MariaDB-Live-Datenbank ermöglicht.

## Übersicht

MariaDBAutobackup ist ein Shell-Skript, das entwickelt wurde, um regelmäßige Backups einer MariaDB-Datenbank zu automatisieren. Es erleichtert die Sicherung und Wiederherstellung von Datenbanken, um den Verlust wichtiger Daten zu verhindern.

## Inhalt

- [Installation](#installation)
- [Konfiguration](#konfiguration)
- [Verwendung](#verwendung)
- [Automatisierung](#automatisierung)
- [Beitragende](#beitragende)
- [Lizenz](#lizenz)

## Installation

1.  Klone dieses Repository auf deinen lokalen Rechner:

    ```sh
    git clone [https://github.com/mleem97/MariaDBAutobackup.git](https://github.com/mleem97/MariaDBAutobackup.git)
    ```

2.  Navigiere in das Verzeichnis des geklonten Repositories:

    ```sh
    cd MariaDBAutobackup
    ```

3.  Stelle sicher, dass das Skript ausführbar ist:

    ```sh
    chmod +x mdbackup.sh
    ```

## Konfiguration

1.  Öffne die `mdbackup.sh`-Datei in einem Texteditor deiner Wahl.
2.  Passe die Konfigurationsvariablen an deine Umgebung an. Beispielsweise:

    ```sh
    DB_USER="dein_benutzername"
    DB_PASSWORD="dein_passwort"
    DB_NAME="deine_datenbank"
    BACKUP_DIR="/pfad/zu/deinen/backups"
    ```

## Verwendung

Um ein manuelles Backup deiner MariaDB-Datenbank zu erstellen, führe das Skript aus:

```sh
./mdbackup.sh
```

Das Skript erstellt eine Backup-Datei im angegebenen BACKUP_DIR mit einem Zeitstempel im Dateinamen.

## Automatisierung
Um regelmäßige Backups zu automatisieren, füge das Skript zu deinem Cron-Job hinzu. Öffne die Crontab-Konfiguration:

```sh
crontab -e
Füge die folgende Zeile hinzu, um das Skript täglich um 2:00 Uhr auszuführen:
```

```sh
0 2 * * * /pfad/zu/mdbackup.sh
```
## Beitragende
[mleem97](https://github.com/mleem97)

## Lizenz
Dieses Projekt ist unter der GNU-GPL-Lizenz lizenziert. Siehe die LICENSE-Datei für Details.
