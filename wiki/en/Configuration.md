# Configuring MariaDBAutobackup

This guide describes the various configuration options for MariaDBAutobackup.

## Configuration File

The main configuration file is located at `/etc/mdbackup.conf`. This file is created during installation or can be created manually using the following command:

```bash
sudo mdbackup configure
```

## Configuration Options

### Database Settings

```bash
# Database Settings
DATABASE_HOST="localhost"       # Hostname or IP of the MariaDB/MySQL database
DATABASE_PORT="3306"            # Database port
DATABASE_USER="root"            # Username for database connection
DATABASE_PASSWORD="password"    # Password for database connection
```

### Backup Settings

```bash
# Backup Settings
BACKUP_DIR="/var/lib/mysql-backups"  # Directory where backups are stored
LOG_FILE="/var/log/mdbackup.log"     # Path to log file
BACKUP_RETENTION_DAYS="7"            # Number of days to keep backups
```

### Compression Settings

```bash
# Compression Settings
COMPRESSION_ALGORITHM="gzip"    # Possible values: "gzip", "bzip2", "xz", "none"
COMPRESSION_LEVEL="6"           # Compression level (1-9, where 9 is highest compression)
```

### Encryption Settings

```bash
# Encryption Settings
ENCRYPT_BACKUPS="no"            # Enable encryption with "yes"
GPG_KEY_ID=""                   # GPG key ID for encryption
```

### Schedule Settings

```bash
# Schedule Settings
BACKUP_TIME="02:00"             # Time for scheduled backups (24-hour format)
```

### Remote Backup Settings

```bash
# Remote Backup Settings
REMOTE_BACKUP_ENABLED="no"      # Enable remote backups with "yes"

# NFS Settings (enable at least one remote option)
REMOTE_NFS_MOUNT=""             # NFS mount point

# RSYNC Settings
REMOTE_RSYNC_TARGET=""          # Rsync target in format "user@host:/path"

# Cloud Settings
REMOTE_CLOUD_CLI=""             # Cloud CLI tool (e.g., "aws", "gsutil", "rclone")
REMOTE_CLOUD_BUCKET=""          # Cloud bucket or destination
```

### SSH Tunnel Settings

```bash
# SSH Tunnel Settings (for remote databases)
SSH_USER=""                     # SSH username
SSH_HOST=""                     # SSH host
SSH_PORT="22"                   # SSH port
```

### Pre- and Post-Backup Hooks

```bash
# Pre- and Post-Backup Hooks
PRE_BACKUP_SCRIPT=""            # Path to a script to run before backup
POST_BACKUP_SCRIPT=""           # Path to a script to run after backup
```

## Configuration via Command Line

MariaDBAutobackup provides various commands to manage the configuration:

### General Configuration

```bash
sudo mdbackup configure
```

This command guides you interactively through the main configuration options.

### Specific Compression Settings

```bash
sudo mdbackup configure-compression
```

This command allows you to adjust the compression algorithm and level.

## Configuration Validation

MariaDBAutobackup checks your configuration for validity before each backup. If problems are found, you will receive appropriate warnings or error messages.

## Environment Variables

In addition to the configuration file, you can make temporary changes via environment variables:

```bash
DATABASE_PASSWORD="my_password" mdbackup backup
```

This method is useful for scripts or one-time changes without editing the configuration file.

## Example Configuration

Here's a complete example configuration for daily backup with compression and remote transfer to an NFS share:

```bash
# Database Settings
DATABASE_HOST="localhost"
DATABASE_PORT="3306"
DATABASE_USER="backup_user"
DATABASE_PASSWORD="secure_password"

# Backup Settings
BACKUP_DIR="/var/lib/mysql-backups"
LOG_FILE="/var/log/mdbackup.log"
BACKUP_RETENTION_DAYS="14"

# Compression Settings
COMPRESSION_ALGORITHM="gzip"
COMPRESSION_LEVEL="6"

# Encryption Settings
ENCRYPT_BACKUPS="no"
GPG_KEY_ID=""

# Schedule Settings
BACKUP_TIME="02:00"

# Remote Backup Settings
REMOTE_BACKUP_ENABLED="yes"
REMOTE_NFS_MOUNT="/mnt/backups"
```

## Security Notes

- Protect your configuration file as it contains sensitive information like database passwords
- Use a dedicated database user with minimal permissions for backups
- Check the permissions of the configuration file: `sudo chmod 600 /etc/mdbackup.conf`

## Next Steps

After configuring MariaDBAutobackup, you can learn more about [Backup Types](Backup-Types.md) and [Automation](Automation.md) of backups.