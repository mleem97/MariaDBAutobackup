# Backup Restoration

This guide explains how to restore databases from backups created with MariaDBAutobackup.

## Overview

Restoring backups is a critical process that must be performed carefully to avoid data loss. MariaDBAutobackup provides simple commands to restore databases from various backup types.

## Prerequisites

- A working backup created with MariaDBAutobackup
- Sufficient permissions for restoration (typically root access or sudo privileges)
- If the backup is encrypted, you'll need the corresponding GPG key

## Restoring with the Interactive Command

The easiest way to restore a backup is using the interactive restoration command:

```bash
sudo mdbackup restore
```

This command will guide you through the following steps:

1. Displaying available backups
2. Selecting the backup to restore
3. Confirming the restoration
4. Automatic decryption (if needed)
5. Automatic decompression (if needed)
6. Restoring the database(s)

## Restoring a Specific Backup

If you already know which backup you want to restore:

```bash
sudo mdbackup restore /path/to/backup/backup_file.sql.gz
```

## Restoring to a Specific Database

If you want to restore a backup to a specific database:

```bash
sudo mdbackup restore --database=target_database /path/to/backup/backup_file.sql.gz
```

Note: For full backups, all databases are restored by default. For table-specific backups, the original database is used unless you specify a different one.

## Restoring Incremental or Differential Backups

For incremental or differential backups, all required backups in the chain must be available:

1. For differential backups: The last full backup and the differential backup
2. For incremental backups: The last full backup and all subsequent incremental backups

MariaDBAutobackup automatically detects dependencies and performs the restoration in the correct order.

## Manual Restoration (Without Using the restore Command)

In some cases, you might want to restore a backup manually:

### 1. Decryption (if encrypted)

```bash
gpg --decrypt backup_file.sql.gz.gpg > backup_file.sql.gz
```

### 2. Decompression (if compressed)

```bash
# For gzip (default compression)
gunzip < backup_file.sql.gz > backup_file.sql

# For bzip2
bunzip2 < backup_file.sql.bz2 > backup_file.sql

# For xz
xz -d < backup_file.sql.xz > backup_file.sql
```

### 3. Restoration with the mysql command

```bash
# Full backup
mysql -u root -p < backup_file.sql

# For a specific database
mysql -u root -p database_name < backup_file.sql
```

## Restoring on a Different Server

To restore a backup on a different server:

1. Copy the backup to the target server
2. Install MariaDBAutobackup on the target server or use the manual method
3. Restore the backup as described above

## Verifying the Restoration

After restoration, you should verify that it was successful:

```bash
# Connect to the database
mysql -u root -p

# List databases
SHOW DATABASES;

# Select a specific database
USE database_name;

# List tables
SHOW TABLES;

# Sample check of data
SELECT * FROM table_name LIMIT 10;
```

## Troubleshooting

### Permission Issues

If you get permission errors:

```
ERROR 1044 (42000): Access denied for user 'username'@'localhost' to database 'database_name'
```

Ensure the user has sufficient permissions:

```sql
GRANT ALL PRIVILEGES ON database_name.* TO 'username'@'localhost';
FLUSH PRIVILEGES;
```

### Decryption Errors

If you have issues with decryption:

```
gpg: decryption failed: No secret key
```

Make sure the correct GPG key is imported:

```bash
gpg --import your_private_key.asc
```

### File Not Found

If MariaDBAutobackup cannot find the backup:

```
Error: Backup file not found at [path]
```

Check the path and permissions:

```bash
ls -la /path/to/backup/
```

## Best Practices

- **Test Restoration Regularly**: Regularly perform restoration tests to ensure your backups are working
- **Separate Environment**: Test restorations in a separate environment before applying them in production
- **Document**: Keep your restoration processes and results documented
- **Backup Before Restoration**: Create a backup of current data before performing a restoration
- **Check Consistency**: Use the `mdbackup verify` command to check the integrity of backups before restoration

## Next Steps

After familiarizing yourself with restoration, you should learn about [troubleshooting](Troubleshooting.md) and [FAQs](FAQ.md) for MariaDBAutobackup.