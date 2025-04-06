# Installing MariaDBAutobackup

This guide walks you through the process of installing MariaDBAutobackup.

## Prerequisites

- Linux operating system (tested on Debian, Ubuntu, CentOS)
- MariaDB or MySQL database installed
- Bash shell
- Root access or sudo privileges

## Installation via Git

1. Clone the repository:

   ```bash
   git clone https://github.com/mleem97/MariaDBAutobackup.git
   ```

2. Change to the directory:

   ```bash
   cd MariaDBAutobackup
   ```

3. Make the script executable:

   ```bash
   chmod +x mdbackup.sh
   ```

4. Run the installation command:

   ```bash
   sudo ./mdbackup.sh install
   ```

During installation, you will be prompted for configuration details.

## Manual Installation

Alternatively, you can install the script manually:

1. Download the latest version:

   ```bash
   curl -O https://raw.githubusercontent.com/mleem97/MariaDBAutobackup/main/mdbackup.sh
   ```

2. Make the script executable:

   ```bash
   chmod +x mdbackup.sh
   ```

3. Copy it to a directory in your PATH:

   ```bash
   sudo cp mdbackup.sh /usr/local/bin/mdbackup
   ```

4. Create a configuration file:

   ```bash
   sudo mdbackup configure
   ```

## Verifying the Installation

To verify that the installation was successful:

```bash
mdbackup version
```

This should display the current version of the script (e.g., 1.2.0).

## Setting Up the Systemd Service

After installation, a systemd service and timer are automatically set up. You can check their status with:

```bash
sudo systemctl status mdbackup.timer
```

If you want to set up the service manually:

```bash
sudo mdbackup create-service
```

## Uninstallation

To uninstall MariaDBAutobackup:

```bash
sudo mdbackup uninstall
```

This command removes the script, systemd files, and optionally the configuration file and backup data.

## Next Steps

After successful installation, you should proceed to [Configuration](Configuration.md) to customize MariaDBAutobackup to your needs.