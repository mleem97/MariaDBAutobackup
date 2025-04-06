# Troubleshooting

This guide helps you solve common problems and errors that may occur when using MariaDBAutobackup.

## Common Backup Problems

### Backup Cannot Be Created

**Problem**: The backup process fails with an error message.

**Possible Causes and Solutions**:

1. **Database Connection Problems**:
   ```
   Error: Failed to connect to database at [host]
   ```
   - Check if the database is running: `sudo systemctl status mariadb`
   - Ensure the credentials are correct
   - Test the connection manually: `mysql -u [user] -p -h [host]`

2. **Permission Issues**:
   ```
   Error: Permission denied when writing to [backup_dir]
   ```
   - Check the backup directory permissions: `ls -la [backup_dir]`
   - Change the owner or permissions: `sudo chown -R [user]:[group] [backup_dir]`
   - Or run the backup with sudo: `sudo mdbackup backup`

3. **Not Enough Disk Space**:
   ```
   Error: No space left on device
   ```
   - Check available disk space: `df -h`
   - Clean up old backups: `sudo mdbackup cleanup`
   - Configure a shorter retention period: `BACKUP_RETENTION_DAYS="3"`

4. **Mysqldump Errors**:
   ```
   Error: mysqldump command failed with exit code [code]
   ```
   - Check if mysqldump is installed: `which mysqldump`
   - Check the full error message in the log: `sudo cat /var/log/mdbackup.log`

### Issues with Incremental/Differential Backups

**Problem**: Incremental or differential backups fail.

**Solutions**:

1. **No Full Backup as Base**:
   - First create a full backup: `sudo mdbackup backup --type=full`

2. **Binary Logs Not Enabled**:
   - Enable binary logs in MariaDB/MySQL configuration:
     ```
     # /etc/mysql/mariadb.conf.d/50-server.cnf or /etc/my.cnf
     [mysqld]
     log-bin=mysql-bin
     binlog_format=ROW
     ```
   - Restart the database: `sudo systemctl restart mariadb`

### Problems with Encrypted Backups

**Problem**: Encryption or decryption fails.

**Solutions**:

1. **GPG Not Found**:
   - Install GPG: `sudo apt-get install gnupg`

2. **GPG Key Not Found**:
   ```
   Error: No public key found for encryption
   ```
   - Check the configured key: `gpg --list-keys [key_id]`
   - Make sure the correct key is specified in the configuration

3. **Decryption Failed**:
   ```
   gpg: decryption failed: No secret key
   ```
   - Import the private key: `gpg --import private_key.asc`

## Remote Backup Issues

### NFS Mount Problems

**Problem**: Backups cannot be stored on NFS.

**Solutions**:

1. **Mount Failed**:
   - Check if the NFS share is mounted: `mount | grep [mount_point]`
   - Mount it manually: `sudo mount -t nfs [server]:[share] [mount_point]`
   - Configure the mount in `/etc/fstab` for automatic mounting

2. **Permission Issues on NFS**:
   - Check the NFS export permissions on the server
   - Ensure the NFS client has the correct permissions

### RSYNC Problems

**Problem**: The rsync transfer fails.

**Solutions**:

1. **SSH Connection Failed**:
   - Check if SSH keys are set up correctly
   - Test the SSH connection manually: `ssh [user]@[host]`

2. **Destination Directory Does Not Exist or No Write Permission**:
   - Create the destination directory: `ssh [user]@[host] "mkdir -p [directory]"`
   - Set the correct permissions

### Cloud Storage Problems

**Problem**: Upload to cloud storage fails.

**Solutions**:

1. **CLI Tool Not Found**:
   - Install the appropriate CLI tool:
     - AWS: `sudo apt-get install awscli`
     - Google Cloud: `sudo apt-get install google-cloud-sdk`

2. **Authentication Problems**:
   - Configure the CLI tool with valid credentials:
     - AWS: `aws configure`
     - Google Cloud: `gcloud auth login`

3. **Bucket/Container Not Found**:
   - Check if the bucket exists
   - Make sure the correct path is configured

## Automated Backup Problems

### Systemd Timer Does Not Start

**Problem**: Automated backups are not being executed.

**Solutions**:

1. **Timer Not Enabled**:
   - Check the status: `sudo systemctl status mdbackup.timer`
   - Enable the timer: `sudo systemctl enable mdbackup.timer`
   - Start the timer: `sudo systemctl start mdbackup.timer`

2. **Timer Misconfigured**:
   - Check the timer file: `sudo cat /etc/systemd/system/mdbackup.timer`
   - Adjust the backup time in the configuration: `/etc/mdbackup.conf`
   - Reload systemd: `sudo systemctl daemon-reload`

3. **Service Failed**:
   - Check the service logs: `sudo journalctl -u mdbackup.service`
   - Fix the errors based on the log messages

## Restoration Problems

### Restoration Fails

**Problem**: Restoring a backup fails.

**Solutions**:

1. **Backup File Corrupted**:
   - Check the integrity of the backup: `sudo mdbackup verify [backup_file]`
   - Use an older backup if available

2. **Decompression Errors**:
   - Ensure the appropriate decompression tools are installed:
     - gzip: `sudo apt-get install gzip`
     - bzip2: `sudo apt-get install bzip2`
     - xz: `sudo apt-get install xz-utils`

3. **MySQL/MariaDB Errors During Restoration**:
   - Check the full error message in the log: `sudo cat /var/log/mdbackup.log`
   - Typical problems might include:
     - Syntax errors in the SQL dump
     - Conflicts with existing databases/tables
     - Incompatible database versions

## Solving General Issues

### Dependency Problems

**Problem**: Missing dependencies for MariaDBAutobackup.

**Solutions**:

1. **Run the Automatic Dependency Installation**:
   ```bash
   sudo mdbackup check-dependencies --install
   ```

2. **Manually Install Dependencies**:
   ```bash
   sudo apt-get update
   sudo apt-get install mariadb-client gzip bzip2 xz-utils gnupg rsync curl
   ```

### Log File Issues

**Problem**: The log file grows too large or is missing.

**Solutions**:

1. **Configure Log Rotation**:
   - Create a logrotate configuration:
     ```bash
     sudo nano /etc/logrotate.d/mdbackup
     ```
     
     With the content:
     ```
     /var/log/mdbackup.log {
         weekly
         rotate 4
         compress
         missingok
         notifempty
         create 0640 root root
     }
     ```

2. **Log File Not Writable**:
   - Check and correct the permissions:
     ```bash
     sudo touch /var/log/mdbackup.log
     sudo chmod 640 /var/log/mdbackup.log
     sudo chown root:root /var/log/mdbackup.log
     ```

### Update Problems

**Problem**: Issues when updating MariaDBAutobackup.

**Solutions**:

1. **Manual Update**:
   ```bash
   cd /path/to/MariaDBAutobackup
   git pull
   sudo ./mdbackup.sh install
   ```

2. **Restore Configuration After Update**:
   - Back up your configuration before updating
   - Make sure to add any new configuration options

## Diagnostic Tools

### Log Analysis

To check the logs for errors:

```bash
sudo grep "ERROR\|Error\|error" /var/log/mdbackup.log
```

### Configuration Validation

Validate your configuration:

```bash
sudo mdbackup validate-config
```

### Test Mode

Run commands in test mode to diagnose issues without making actual changes:

```bash
sudo mdbackup backup --dry-run
```

### Debug Mode

Enable more verbose logging for troubleshooting:

```bash
sudo DEBUG=1 mdbackup backup
```

## Support and Help

If you cannot solve the problem:

1. Check the [FAQ](FAQ.md) for known issues and solutions
2. Search the [GitHub Issues](https://github.com/mleem97/MariaDBAutobackup/issues) for similar problems
3. Create a new issue with:
   - Exact error message
   - Output of command: `sudo mdbackup version`
   - Relevant parts of the log file
   - Details about your environment (operating system, MariaDB/MySQL version)
   - Steps taken to reproduce the problem