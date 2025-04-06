# Backup Automation

This guide explains how to automate the backup process with MariaDBAutobackup.

## Overview

One of the main features of MariaDBAutobackup is the ability to automate database backups. This ensures that your backups are created regularly and reliably without manual intervention.

## Automation with systemd

MariaDBAutobackup uses systemd timers for automation. This offers several advantages over traditional cron jobs, including better logging, dependency management, and error handling.

### Standard Installation

During the installation of MariaDBAutobackup, a systemd service and timer are automatically set up. You can check their status with:

```bash
sudo systemctl status mdbackup.timer
sudo systemctl status mdbackup.service
```

### Manual Setup of the systemd Service

If you want to manually set up the systemd service:

```bash
sudo mdbackup create-service
```

This command creates the files:
- `/etc/systemd/system/mdbackup.service`
- `/etc/systemd/system/mdbackup.timer`

### Adjusting the Schedule

The backup schedule is set in the configuration file `/etc/mdbackup.conf`:

```bash
# Schedule Settings
BACKUP_TIME="02:00"  # Daily backups at 2:00 AM (24-hour format)
```

To change this setting:

1. Edit the configuration file:
   ```bash
   sudo nano /etc/mdbackup.conf
   ```

2. Change the value of `BACKUP_TIME`

3. Apply the changes by restarting the timer unit:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart mdbackup.timer
   ```

### Advanced Scheduling

For more complex schedules, you can edit the timer file directly:

```bash
sudo nano /etc/systemd/system/mdbackup.timer
```

Example of a custom schedule (backups on Monday and Thursday at 3:30 AM):

```ini
[Unit]
Description=MariaDBAutobackup Timer

[Timer]
OnCalendar=Mon,Thu *-*-* 03:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

After any changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart mdbackup.timer
```

## Automation with Pre- and Post-Backup Hooks

MariaDBAutobackup supports running custom scripts before and after the backup process.

### Pre-Backup Scripts

Pre-backup scripts run before the backup begins. These can be useful for:
- Preparing the database (e.g., pausing write operations)
- Checking prerequisites
- Sending notifications

Configuration:

```bash
# In /etc/mdbackup.conf
PRE_BACKUP_SCRIPT="/path/to/my/pre_backup_script.sh"
```

### Post-Backup Scripts

Post-backup scripts run after the backup is completed. These can be useful for:
- Notifications about backup status
- Additional backup validations
- Cleanup operations

Configuration:

```bash
# In /etc/mdbackup.conf
POST_BACKUP_SCRIPT="/path/to/my/post_backup_script.sh"
```

### Example of a Post-Backup Notification Script

Here's a simple example of a script that sends an email notification after a backup:

```bash
#!/bin/bash
# /usr/local/bin/backup_notification.sh

BACKUP_STATUS=$1
BACKUP_FILE=$2
ADMIN_EMAIL="admin@example.com"

if [ "$BACKUP_STATUS" == "success" ]; then
    echo "MariaDB Backup successful: $BACKUP_FILE" | mail -s "Backup Successful" $ADMIN_EMAIL
else
    echo "MariaDB Backup failed. Check the logs." | mail -s "⚠️ Backup FAILED ⚠️" $ADMIN_EMAIL
fi
```

Make the script executable:

```bash
sudo chmod +x /usr/local/bin/backup_notification.sh
```

And add it to your configuration:

```bash
POST_BACKUP_SCRIPT="/usr/local/bin/backup_notification.sh"
```

## Automation with Different Backup Types

You can implement a backup strategy with different backup types:

### Full and Incremental Backups

Example configuration for different days:

```bash
# Full backup on Sunday, incremental on other days
if [ $(date +%u) -eq 7 ]; then
  # Sunday: Full backup
  mdbackup backup --type=full
else
  # Other days: Incremental backup
  mdbackup backup --type=incremental
fi
```

Save this script as `/usr/local/bin/backup_strategy.sh` and make it executable:

```bash
sudo chmod +x /usr/local/bin/backup_strategy.sh
```

Then modify the systemd service file to run this script:

```bash
sudo nano /etc/systemd/system/mdbackup.service
```

Change the `ExecStart` line:

```ini
ExecStart=/usr/local/bin/backup_strategy.sh
```

And update systemd:

```bash
sudo systemctl daemon-reload
```

## Monitoring and Alerts

### Log Monitoring

Backup logs are stored in `/var/log/mdbackup.log` by default. You can configure tools like `logwatch` or `fail2ban` to monitor them and alert on errors.

### Systemd Integration

You can set up email notifications for failed systemd services:

1. Install `postfix` and `mailx`:
   ```bash
   sudo apt-get install postfix mailx
   ```

2. Configure systemd email notifications:
   ```bash
   sudo nano /etc/systemd/system/mdbackup.service
   ```

   Add:
   ```ini
   [Service]
   # ...existing configuration...
   OnFailure=status-email-admin@%n.service
   ```

3. Create the email service:
   ```bash
   sudo nano /etc/systemd/system/status-email-admin@.service
   ```

   With the content:
   ```ini
   [Unit]
   Description=Status Email for %i Failure

   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/systemd-email admin@example.com %i
   ```

4. Create the email script:
   ```bash
   sudo nano /usr/local/bin/systemd-email
   ```

   With the content:
   ```bash
   #!/bin/bash
   
   to=$1
   unit=$2
   
   /usr/bin/systemctl status $unit | \
   /usr/bin/mail -s "Systemd service failed: $unit" $to
   ```

5. Make the script executable:
   ```bash
   sudo chmod +x /usr/local/bin/systemd-email
   ```

6. Update systemd:
   ```bash
   sudo systemctl daemon-reload
   ```

## Troubleshooting

### Timer Doesn't Start

If the timer doesn't start as expected, check:

```bash
# Timer status
sudo systemctl status mdbackup.timer

# List all timers
sudo systemctl list-timers

# Journal logs
sudo journalctl -u mdbackup.timer
sudo journalctl -u mdbackup.service
```

### Permission Issues

If backups fail due to permission issues:

1. Ensure the user running the service has access to the database
2. Check write permissions in the backup directory:
   ```bash
   sudo ls -la /var/lib/mysql-backups
   ```

## Best Practices

- **Test regularly**: Occasionally perform manual tests to ensure automated backups are working as expected
- **Monitor logs**: Set up regular review of backup logs
- **Implement rotation schemes**: Use the `BACKUP_RETENTION_DAYS` setting to remove old backups
- **Validate backups**: Set up regular test restorations to verify backup integrity

## Next Steps

After setting up automation, you should learn more about [restoring](Restoration.md) backups and [troubleshooting](Troubleshooting.md) common issues.