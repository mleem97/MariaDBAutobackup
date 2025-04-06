# Remote Backups

This guide explains how to configure and use remote backup options in MariaDBAutobackup.

## Overview

MariaDBAutobackup supports multiple methods to transfer your backups to remote locations, which is essential for an effective disaster recovery strategy. Local backups protect you from database failures, but remote backups provide additional protection against hardware failures, site issues, and other disasters.

## Supported Remote Storage Options

MariaDBAutobackup supports three main types of remote storage:

1. **NFS (Network File System)**: Mounting a network storage and directly storing backups
2. **RSYNC**: Transferring backups to remote servers using the rsync protocol
3. **Cloud Storage**: Uploading backups to cloud services such as AWS S3, Google Cloud Storage, or others

## Configuring Remote Backup Functions

To enable remote backups, you need to edit the configuration file `/etc/mdbackup.conf` or use the interactive configuration command.

### Enabling the Remote Backup Feature

Set in the configuration file:

```bash
REMOTE_BACKUP_ENABLED="yes"
```

### NFS Configuration

To use an NFS share as remote backup storage:

```bash
REMOTE_NFS_MOUNT="/mnt/backups"  # Path where the NFS share is mounted
```

Ensure the NFS share is properly set up in `/etc/fstab` or mount it manually before running backups:

```bash
sudo mount -t nfs nfs-server:/shared/backup /mnt/backups
```

### RSYNC Configuration

To transfer backups to a remote server using rsync:

```bash
REMOTE_RSYNC_TARGET="user@host:/path/to/backups"
```

For password-less authentication, you should set up SSH keys:

```bash
# Generate SSH key (if not already done)
ssh-keygen -t rsa -b 4096

# Copy key to target server
ssh-copy-id user@host
```

### Cloud Storage Configuration

For cloud storage, you need to install and configure the appropriate CLI tool:

```bash
REMOTE_CLOUD_CLI="aws"           # aws, gsutil (for Google Cloud), rclone, etc.
REMOTE_CLOUD_BUCKET="s3://my-backup-bucket/mysql"  # Cloud storage destination
```

#### AWS S3 Example

1. Install the AWS CLI:
   ```bash
   sudo apt-get install awscli  # Debian/Ubuntu
   ```

2. Configure AWS credentials:
   ```bash
   aws configure
   ```

3. Set the MariaDBAutobackup configuration:
   ```bash
   REMOTE_CLOUD_CLI="aws"
   REMOTE_CLOUD_BUCKET="s3://my-backup-bucket/mysql"
   ```

#### Google Cloud Storage Example

1. Install the Google Cloud SDK:
   ```bash
   # Debian/Ubuntu
   echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
   curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
   sudo apt-get update && sudo apt-get install google-cloud-sdk
   ```

2. Initialize the SDK:
   ```bash
   gcloud init
   ```

3. Set the MariaDBAutobackup configuration:
   ```bash
   REMOTE_CLOUD_CLI="gsutil"
   REMOTE_CLOUD_BUCKET="gs://my-backup-bucket/mysql"
   ```

## Verifying the Remote Backup Configuration

After configuration, you can perform a test:

```bash
sudo mdbackup backup
```

Check the log for possible errors:

```bash
sudo tail -n 50 /var/log/mdbackup.log
```

## How the Remote Backup Process Works

When remote backups are enabled, MariaDBAutobackup performs the following steps:

1. The database backup is created locally
2. Depending on the configuration, the backup is compressed and/or encrypted
3. The backup is transferred to the remote location:
   - For NFS: Files are copied directly to the mounted network drive
   - For RSYNC: Files are transferred to the remote server using rsync
   - For Cloud Storage: Files are uploaded using the configured CLI tool
4. Success or failure is logged

## Automating Remote Backups

Remote backups run automatically when they are enabled and a backup is initiated via the systemd timer or manually.

## Troubleshooting

### NFS Issues

If backups cannot be written to the NFS share:

```
Error: Failed to write backup to NFS mount [/mnt/backups]
```

Check:
- The NFS share is correctly mounted: `mount | grep /mnt/backups`
- Permissions on the NFS share: `ls -la /mnt/backups`
- Network connection to the NFS server: `ping nfs-server`

### RSYNC Issues

If the rsync transfer fails:

```
Error: Failed to transfer backup via rsync
```

Check:
- SSH connection to the target server: `ssh user@host`
- Permissions in the destination directory
- SSH key authentication is properly set up

### Cloud Storage Issues

If the upload to cloud storage fails:

```
Error: Failed to upload backup to cloud storage
```

Check:
- The CLI tool is correctly installed and configured
- Credentials for the cloud service are valid
- Bucket/container exists and is accessible
- Internet connection is available

## Best Practices

- **Encryption**: Enable encryption for remote backups, especially in the cloud
- **Verification**: Regularly perform test restorations to confirm remote backups are working
- **Redundancy**: Use multiple remote storage locations for critical databases
- **Monitoring**: Monitor the remote backup process and set up notifications for failures

## Next Steps

After configuring remote backups, you should familiarize yourself with [restoration](Restoration.md) of backups and [automation](Automation.md) of the backup process.