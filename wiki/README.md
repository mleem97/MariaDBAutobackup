# MariaDBAutobackup Wiki Struktur

Diese Datei beschreibt die Struktur des Wiki-Repositories für das MariaDBAutobackup-Projekt.

## Ordnerstruktur

```
wiki/
├── de/                     # Deutsche Dokumentation
│   ├── Installation.md     # Installationsanleitung
│   ├── Konfiguration.md    # Konfigurationsoptionen
│   ├── Backup-Typen.md     # Verschiedene Backup-Typen erklärt
│   ├── Wiederherstellung.md # Backup-Wiederherstellung
│   ├── Verschlüsselung.md  # GPG-Verschlüsselung einrichten
│   ├── Remote-Backups.md   # Remote-Backup-Optionen
│   ├── SSH-Tunnel.md       # SSH-Tunnel für Remote-Datenbanken
│   ├── Automatisierung.md  # Automatisierung mit systemd
│   ├── Fehlerbehebung.md   # Häufige Probleme und Lösungen
│   └── FAQ.md              # Häufig gestellte Fragen
│
├── en/                     # Englische Dokumentation
│   ├── Installation.md     # Installation guide
│   ├── Configuration.md    # Configuration options
│   ├── Backup-Types.md     # Different backup types explained
│   ├── Restoration.md      # Backup restoration
│   ├── Encryption.md       # Setting up GPG encryption
│   ├── Remote-Backups.md   # Remote backup options
│   ├── SSH-Tunnel.md       # SSH tunneling for remote databases
│   ├── Automation.md       # Automation with systemd
│   ├── Troubleshooting.md  # Common issues and solutions
│   └── FAQ.md              # Frequently asked questions
│
├── img/                    # Bilder und Diagramme für beide Sprachen
│   ├── backup-flow.png     # Backup-Prozessdiagramm
│   ├── config-example.png  # Beispiel für Konfiguration
│   └── ...
│
└── README.md               # Diese Datei (Überblick über die Wiki-Struktur)
```

## Nutzung

Die Wiki-Seiten sind in Markdown formatiert und können direkt in GitHub als Wiki verwendet werden. Die Struktur ist in deutsche und englische Abschnitte unterteilt, um Benutzer in beiden Sprachen zu unterstützen.

## Hinweise für Beitragende

- Bitte halte die Parallelstruktur zwischen den Sprachversionen bei
- Füge Bilder im `img/`-Verzeichnis hinzu und verweise mit relativen Links darauf
- Verwende konsistente Formatierung und Terminologie innerhalb deiner Sprache
