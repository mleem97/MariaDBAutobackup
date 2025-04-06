# Backup-Typen in MariaDBAutobackup

MariaDBAutobackup unterstützt verschiedene Arten von Backups, um unterschiedlichen Anforderungen gerecht zu werden. Dieser Leitfaden erklärt die verschiedenen Backup-Typen und wann Sie diese verwenden sollten.

## Überblick über die Backup-Typen

MariaDBAutobackup bietet vier Hauptarten von Backups:

1. **Vollständiges Backup**: Eine komplette Sicherung aller Datenbanken
2. **Differentielles Backup**: Sichert Änderungen seit dem letzten vollständigen Backup
3. **Inkrementelles Backup**: Sichert Änderungen seit dem letzten Backup beliebigen Typs
4. **Tabellen-spezifisches Backup**: Sichert nur ausgewählte Tabellen

## Vollständige Backups

### Beschreibung
Ein vollständiges (Full) Backup sichert alle Datenbanken, Tabellen und Daten in Ihrer MySQL/MariaDB-Installation. Dies ist die umfassendste, aber auch speicherintensivste Backup-Methode.

### Wann verwenden?
- Als Basis für differentielle oder inkrementelle Backup-Strategien
- Für kritische, regelmäßige Sicherungen (z.B. wöchentlich)
- Wenn Speicherplatz keine Einschränkung darstellt

### Ausführung
```bash
mdbackup backup
# Wählen Sie Option 1 für ein vollständiges Backup
```

### Technische Details
- Verwendet den `mysqldump`-Befehl mit der Option `--all-databases`
- Erzeugt eine SQL-Datei mit allen Datenbankinhalten und -strukturen

## Differentielle Backups

### Beschreibung
Ein differentielles Backup sichert alle Änderungen, die seit dem letzten vollständigen Backup vorgenommen wurden. Jedes differentielle Backup baut immer auf dem letzten vollständigen Backup auf.

### Wann verwenden?
- Wenn vollständige Backups zu ressourcenintensiv für tägliche Ausführung sind
- Als Teil einer gestaffelten Backup-Strategie
- Für schnellere Backup-Durchführung mit angemessener Datensicherheit

### Ausführung
```bash
mdbackup backup
# Wählen Sie Option 2 für ein differentielles Backup
```

### Technische Details
- Erfordert ein vorheriges vollständiges Backup als Basis
- Verwendet `mysqldump` mit Optionen für binärlogbasierte Unterschiede
- Speichert nur Änderungen seit dem letzten vollständigen Backup

## Inkrementelle Backups

### Beschreibung
Ein inkrementelles Backup sichert nur die Änderungen seit dem letzten Backup, unabhängig davon, ob es ein vollständiges, differentielles oder inkrementelles Backup war.

### Wann verwenden?
- Für häufige Backups mit minimaler Ressourcennutzung
- Wenn Speicherplatz stark begrenzt ist
- Für Szenarien, die eine feine Granularität der Wiederherstellungspunkte erfordern

### Ausführung
```bash
mdbackup backup
# Wählen Sie Option 3 für ein inkrementelles Backup
```

### Technische Details
- Baut auf dem vorherigen Backup auf (egal welchen Typs)
- Speichert nur die neuesten Änderungen
- Erfordert alle vorherigen Backups in der Kette für die Wiederherstellung

## Tabellen-spezifische Backups

### Beschreibung
Mit einem tabellen-spezifischen Backup können Sie gezielt bestimmte Datenbanken und Tabellen sichern, anstatt die gesamte Datenbankinstanz.

### Wann verwenden?
- Wenn nur bestimmte Tabellen kritische Daten enthalten
- Für sehr große Datenbanken, bei denen vollständige Backups unpraktisch sind
- Für spezielle Anforderungen (z.B. Entwicklung, Datenextraktion)

### Ausführung
```bash
mdbackup backup
# Wählen Sie Option 4 für ein tabellen-spezifisches Backup
# Folgen Sie den Anweisungen, um Datenbank und Tabellen anzugeben
```

### Technische Details
- Erlaubt die Auswahl einer bestimmten Datenbank und spezifischer Tabellen
- Optimiert Speichernutzung und Backup-Zeit für große Datenbanken
- Ideal für datengesteuerte Anwendungen mit klar definierten kritischen Tabellen

## Backup-Strategien und Empfehlungen

Hier sind einige empfohlene Backup-Strategien:

### Für kleine Datenbanken
- Tägliche vollständige Backups

### Für mittlere Datenbanken
- Wöchentliches vollständiges Backup
- Tägliche differentielle Backups

### Für große Datenbanken
- Wöchentliches vollständiges Backup
- Tägliche inkrementelle Backups
- Gegebenenfalls tabellen-spezifische Backups für kritische Daten

## Nächste Schritte

Nachdem Sie sich mit den verschiedenen Backup-Typen vertraut gemacht haben, sollten Sie die [Wiederherstellung](Wiederherstellung.md) von Backups und die [Automatisierung](Automatisierung.md) von Backup-Prozessen kennenlernen.