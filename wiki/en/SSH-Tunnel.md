# SSH Tunneling for Remote Databases

This guide explains how to use SSH tunneling to access and back up remote MariaDB/MySQL databases.

## Overview

SSH tunneling provides a secure method to access a remote database without exposing the database port directly to the internet. MariaDBAutobackup supports SSH tunneling to make your database backups secure.

## Prerequisites

- SSH access to the remote server where the database is running
- SSH key authentication set up (recommended) or password
- SSH client installed on the server running MariaDBAutobackup

## Configuration

### Manual Configuration

Add the following settings to your `/etc/mdbackup.conf` file:

```bash
# SSH Tunnel Settings
SSH_USER="ssh_username"
SSH_HOST="ssh_hostname_or_ip"
SSH_PORT="22"  # Standard SSH port (change if needed)
```

Replace:
- `ssh_username` with your SSH username on the remote server
- `ssh_hostname_or_ip` with the hostname or IP address of the remote server
- `22` with the SSH port if it differs from the standard

### Configuration During Backup Execution

If you don't have SSH tunnel settings in your configuration file, MariaDBAutobackup will interactively ask for them when you try to create a backup from a remote database:

```bash
mdbackup backup
# Choose a backup type
# If DATABASE_HOST is not localhost, you'll be asked:
Do you need an SSH tunnel to connect to your-db-host? [y/N]:
```

If you enter "y", you'll be prompted to enter the SSH connection details.

## How It Works

When you execute a backup for a remote database with SSH tunnel:

1. MariaDBAutobackup creates a temporary SSH tunnel from local port 13306 to the MySQL/MariaDB port (3306) on the remote server
2. The backup process connects to the database through the tunnel (127.0.0.1:13306)
3. After the backup is completed, the SSH tunnel is automatically closed

## Usage Example

1. Configure your database connection for a remote host:

   ```
   DATABASE_HOST="db.example.com"
   DATABASE_USER="db_user"
   DATABASE_PASSWORD="db_password"
   ```

2. Run the backup command:

   ```bash
   sudo mdbackup backup
   ```

3. When prompted for an SSH tunnel, select "yes" and provide SSH connection information.

## Troubleshooting

### Cannot Establish SSH Tunnel

If the following error occurs:
```
Failed to establish SSH tunnel. Check your SSH credentials.
```

Check:
- SSH username and host are correct
- SSH port is correct
- You have the appropriate SSH access permissions
- SSH key authentication is properly set up

### Database Connection Through Tunnel Fails

If the following error occurs:
```
Failed to connect to database at [your-db-host]
```

Check:
- The MySQL/MariaDB instance is running on the remote server
- The database user has permission to connect via 'localhost'
- Firewall settings are not blocking the local connection
- MySQL/MariaDB is configured for local connections

## Security Tips

- Always use SSH keys instead of passwords when possible
- Restrict the SSH user to minimal permissions needed for backups
- Use a dedicated database user with limited permissions for backups

## Next Steps

After configuring SSH tunneling for your remote databases, you should familiarize yourself with [encryption](Encryption.md) of backups and [remote backup storage options](Remote-Backups.md).