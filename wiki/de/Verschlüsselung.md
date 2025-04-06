# Verschlüsselung von Backups

Diese Anleitung erklärt, wie Sie die Backup-Verschlüsselung in MariaDBAutobackup konfigurieren und verwenden können.

## Überblick

MariaDBAutobackup ermöglicht die sichere Verschlüsselung Ihrer Datenbank-Backups mit GPG (GNU Privacy Guard). Die Verschlüsselung stellt sicher, dass Ihre Datenbank-Backups vor unbefugtem Zugriff geschützt sind, selbst wenn jemand Zugang zu den Backup-Dateien erlangt.

## Voraussetzungen

- GPG muss auf dem System installiert sein
- Ein GPG-Schlüsselpaar muss vorhanden sein oder erstellt werden

## Installation von GPG

Falls GPG noch nicht installiert ist, können Sie es mit den folgenden Befehlen installieren:

### Auf Debian/Ubuntu:
```bash
sudo apt-get update
sudo apt-get install gnupg
```

### Auf CentOS/RHEL:
```bash
sudo yum install gnupg
```

## GPG-Schlüssel erstellen

Wenn Sie noch keinen GPG-Schlüssel haben, können Sie einen mit dem folgenden Befehl erstellen:

```bash
gpg --full-generate-key
```

Folgen Sie den Anweisungen, um einen Schlüssel zu erstellen:
1. Wählen Sie den Schlüsseltyp (empfohlen: RSA und RSA, Standard)
2. Wählen Sie die Schlüssellänge (empfohlen: 4096 Bit)
3. Wählen Sie, wie lange der Schlüssel gültig sein soll
4. Geben Sie Ihre persönlichen Informationen ein (Name, E-Mail)
5. Legen Sie ein sicheres Passwort fest

## GPG-Schlüssel-ID finden

Um Ihren GPG-Schlüssel für die Verschlüsselung zu verwenden, benötigen Sie die Schlüssel-ID. Sie können Ihre GPG-Schlüssel mit dem folgenden Befehl auflisten:

```bash
gpg --list-keys
```

Die Ausgabe sieht etwa so aus:

```
pub   rsa4096 2023-01-15 [SC]
      1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T
uid           [ultimate] Ihr Name <ihre.email@beispiel.de>
sub   rsa4096 2023-01-15 [E]
```

Die Schlüssel-ID ist die lange Zeichenfolge nach `pub`. In diesem Beispiel wäre es: `1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T`

## Verschlüsselung in MariaDBAutobackup konfigurieren

### Über die Konfigurationsdatei

Bearbeiten Sie die Konfigurationsdatei `/etc/mdbackup.conf` und aktualisieren Sie die folgenden Einstellungen:

```bash
# Verschlüsselungs-Einstellungen
ENCRYPT_BACKUPS="yes"
GPG_KEY_ID="IHRE_GPG_SCHLÜSSEL_ID"
```

Ersetzen Sie `IHRE_GPG_SCHLÜSSEL_ID` mit der Schlüssel-ID, die Sie im vorherigen Schritt gefunden haben.

### Über den interaktiven Konfigurationsbefehl

Alternativ können Sie den interaktiven Konfigurationsbefehl verwenden:

```bash
sudo mdbackup configure
```

Wenn Sie nach der Verschlüsselung gefragt werden, wählen Sie "yes" und geben Sie Ihre GPG-Schlüssel-ID ein.

## Wie funktioniert die Verschlüsselung?

Wenn die Verschlüsselung aktiviert ist, führt MariaDBAutobackup die folgenden Schritte aus:

1. Das Backup wird wie gewohnt erstellt (SQL-Dump)
2. Die Backup-Datei wird komprimiert (wenn die Komprimierung aktiviert ist)
3. Die komprimierte Datei wird mit GPG und dem angegebenen Schlüssel verschlüsselt
4. Die verschlüsselte Datei erhält die Endung `.gpg`

## Entschlüsseln eines Backups

Um ein verschlüsseltes Backup manuell zu entschlüsseln, verwenden Sie den folgenden Befehl:

```bash
gpg --decrypt backup_file.sql.gz.gpg > backup_file.sql.gz
```

Wenn die Backup-Datei auch komprimiert ist, müssen Sie sie nach der Entschlüsselung dekomprimieren:

```bash
gunzip backup_file.sql.gz
```

## Automatische Entschlüsselung bei der Wiederherstellung

Wenn Sie den `restore`-Befehl von MariaDBAutobackup verwenden, wird die Entschlüsselung automatisch durchgeführt:

```bash
sudo mdbackup restore
```

Sie werden aufgefordert, das GPG-Passwort einzugeben, um die Datei zu entschlüsseln, bevor die Wiederherstellung beginnt.

## Sicherheitshinweise

- Bewahren Sie Ihren privaten GPG-Schlüssel sicher auf
- Sichern Sie Ihren GPG-Schlüssel an einem separaten, sicheren Ort
- Ohne den GPG-Schlüssel können verschlüsselte Backups nicht wiederhergestellt werden
- Verwenden Sie ein starkes Passwort für Ihren GPG-Schlüssel
- Testen Sie den Entschlüsselungsprozess regelmäßig, um sicherzustellen, dass Ihre Backups wiederherstellbar sind

## Fehlerbehebung

### Verschlüsselung schlägt fehl

Wenn die Verschlüsselung mit einem Fehler fehlschlägt:

```
Error: Failed to encrypt backup file
```

Überprüfen Sie:
- Die GPG-Schlüssel-ID ist korrekt
- GPG ist ordnungsgemäß installiert
- Sie haben genügend Festplattenspeicher für die Verschlüsselung

### Entschlüsselung schlägt fehl

Wenn die Entschlüsselung fehlschlägt:

```
gpg: decryption failed: No secret key
```

Dies bedeutet, dass der private Schlüssel zum Entschlüsseln der Datei nicht verfügbar ist. Stellen Sie sicher, dass Sie den richtigen privaten Schlüssel haben und er importiert ist.

## Nächste Schritte

Nachdem Sie die Verschlüsselung eingerichtet haben, sollten Sie sich mit [Remote-Backups](Remote-Backups.md) und der [Automatisierung](Automatisierung.md) von Backups vertraut machen.