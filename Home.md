# MariaDBAutobackup Wiki

Willkommen im Wiki für MariaDBAutobackup! Hier finden Sie umfassende Informationen zur Installation, Konfiguration und Verwendung des MariaDBAutobackup-Skripts.

## Über MariaDBAutobackup

MariaDBAutobackup ist ein mächtiges Shell-Skript, das die automatische Sicherung und Wiederherstellung von MariaDB/MySQL-Datenbanken ermöglicht. Es bietet eine Vielzahl von Funktionen, darunter verschiedene Backup-Typen, Verschlüsselung, Komprimierung und Remote-Backup-Optionen.

## Aktuelle Version

**Version:** 1.2.0

## Hauptfunktionen

- **Verschiedene Backup-Typen**: Vollständig, differentiell, inkrementell, tabellen-spezifisch
- **Verschlüsselung**: Sichere deine Backups mit GPG-Verschlüsselung
- **Komprimierung**: Unterstützung für verschiedene Algorithmen (gzip, bzip2, xz) mit konfigurierbaren Komprimierungsleveln
- **Remote-Backups**: Übertrage Backups zu NFS-Shares, via rsync oder zu Cloud-Speichern
- **Automatische Bereinigung**: Entferne alte Backups basierend auf konfigurierbaren Aufbewahrungsregeln
- **Integritätsprüfung**: Verifiziere die Integrität von Backups mit Checksummen
- **Pre- und Post-Backup-Hooks**: Führe benutzerdefinierte Skripte vor und nach dem Backup aus
- **Automatische Updates**: Prüfe und installiere Updates des Skripts
- **Remote-Datenbankunterstützung**: Verbinde zu Remote-Datenbanken, optional über SSH-Tunnel

## Schnellstart

### Installation

```bash
git clone https://github.com/mleem97/MariaDBAutobackup.git
cd MariaDBAutobackup
chmod +x mdbackup.sh
sudo ./mdbackup.sh install
```

### Grundlegende Verwendung

- **Backup erstellen**: `mdbackup backup`
- **Backup wiederherstellen**: `mdbackup restore`
- **Konfiguration bearbeiten**: `mdbackup configure`
- **Version anzeigen**: `mdbackup version`

## Wiki-Inhalt

- [Installation](Installation)
- [Konfiguration](Konfiguration)
- [Backup-Typen](Backup-Typen)
- [Backup-Wiederherstellen](Backup-Wiederherstellen)
- [Verschlüsselung](Verschlüsselung)
- [Remote-Backups](Remote-Backups)
- [SSH-Tunnel](SSH-Tunnel)
- [Automatisierung](Automatisierung)
- [Fehlerbehebung](Fehlerbehebung)
- [FAQ](FAQ)

## Mitwirken

Jeder ist eingeladen, zum Projekt beizutragen! Melde Fehler, schlage neue Funktionen vor oder reiche Pull-Requests ein.

## Lizenz

Dieses Projekt ist unter der GNU General Public License v3.0 lizenziert. Weitere Details finden Sie in der LICENSE-Datei.