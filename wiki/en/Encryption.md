# Backup Encryption

This guide explains how to configure and use backup encryption in MariaDBAutobackup.

## Overview

MariaDBAutobackup enables secure encryption of your database backups using GPG (GNU Privacy Guard). Encryption ensures that your database backups are protected from unauthorized access, even if someone gains access to the backup files.

## Prerequisites

- GPG must be installed on the system
- A GPG key pair must be available or created

## Installing GPG

If GPG is not already installed, you can install it with the following commands:

### On Debian/Ubuntu:
```bash
sudo apt-get update
sudo apt-get install gnupg
```

### On CentOS/RHEL:
```bash
sudo yum install gnupg
```

## Creating a GPG Key

If you don't already have a GPG key, you can create one with the following command:

```bash
gpg --full-generate-key
```

Follow the prompts to create a key:
1. Choose the key type (recommended: RSA and RSA, default)
2. Choose the key length (recommended: 4096 bits)
3. Choose how long the key should be valid
4. Enter your personal information (name, email)
5. Set a secure password

## Finding Your GPG Key ID

To use your GPG key for encryption, you'll need the key ID. You can list your GPG keys with the following command:

```bash
gpg --list-keys
```

The output will look something like this:

```
pub   rsa4096 2023-01-15 [SC]
      1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T
uid           [ultimate] Your Name <your.email@example.com>
sub   rsa4096 2023-01-15 [E]
```

The key ID is the long string after `pub`. In this example, it would be: `1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T`

## Configuring Encryption in MariaDBAutobackup

### Via the Configuration File

Edit the configuration file `/etc/mdbackup.conf` and update the following settings:

```bash
# Encryption Settings
ENCRYPT_BACKUPS="yes"
GPG_KEY_ID="YOUR_GPG_KEY_ID"
```

Replace `YOUR_GPG_KEY_ID` with the key ID you found in the previous step.

### Via the Interactive Configuration Command

Alternatively, you can use the interactive configuration command:

```bash
sudo mdbackup configure
```

When prompted about encryption, select "yes" and enter your GPG key ID.

## How Encryption Works

When encryption is enabled, MariaDBAutobackup performs the following steps:

1. The backup is created as usual (SQL dump)
2. The backup file is compressed (if compression is enabled)
3. The compressed file is encrypted with GPG using the specified key
4. The encrypted file gets the extension `.gpg`

## Decrypting a Backup Manually

To manually decrypt an encrypted backup, use the following command:

```bash
gpg --decrypt backup_file.sql.gz.gpg > backup_file.sql.gz
```

If the backup file is also compressed, you'll need to decompress it after decryption:

```bash
gunzip backup_file.sql.gz
```

## Automatic Decryption During Restoration

When you use the `restore` command from MariaDBAutobackup, decryption is performed automatically:

```bash
sudo mdbackup restore
```

You will be prompted to enter the GPG password to decrypt the file before restoration begins.

## Security Notes

- Keep your private GPG key safe
- Backup your GPG key in a separate, secure location
- Without the GPG key, encrypted backups cannot be restored
- Use a strong password for your GPG key
- Regularly test the decryption process to ensure your backups are restorable

## Troubleshooting

### Encryption Fails

If encryption fails with an error:

```
Error: Failed to encrypt backup file
```

Check:
- The GPG key ID is correct
- GPG is properly installed
- You have enough disk space for encryption

### Decryption Fails

If decryption fails:

```
gpg: decryption failed: No secret key
```

This means the private key for decrypting the file is not available. Make sure you have the correct private key and it is imported.

## Next Steps

After setting up encryption, you should familiarize yourself with [Remote Backups](Remote-Backups.md) and [Automation](Automation.md) of backups.