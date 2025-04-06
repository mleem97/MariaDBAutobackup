# Backup Types in MariaDBAutobackup

MariaDBAutobackup supports various types of backups to accommodate different requirements. This guide explains the different backup types and when you should use each one.

## Overview of Backup Types

MariaDBAutobackup offers four main types of backups:

1. **Full Backup**: A complete backup of all databases
2. **Differential Backup**: Backs up changes since the last full backup
3. **Incremental Backup**: Backs up changes since the last backup of any type
4. **Table-specific Backup**: Backs up only selected tables

## Full Backups

### Description
A full backup secures all databases, tables, and data in your MySQL/MariaDB installation. This is the most comprehensive, but also the most storage-intensive backup method.

### When to Use
- As a foundation for differential or incremental backup strategies
- For critical, regular backups (e.g., weekly)
- When storage space is not a constraint

### Execution
```bash
mdbackup backup
# Select option 1 for a full backup
```

### Technical Details
- Uses the `mysqldump` command with the `--all-databases` option
- Creates an SQL file with all database contents and structures

## Differential Backups

### Description
A differential backup secures all changes made since the last full backup. Each differential backup always builds on the last full backup.

### When to Use
- When full backups are too resource-intensive for daily execution
- As part of a tiered backup strategy
- For faster backup execution with reasonable data security

### Execution
```bash
mdbackup backup
# Select option 2 for a differential backup
```

### Technical Details
- Requires a previous full backup as a basis
- Uses `mysqldump` with options for binary log-based differences
- Stores only changes since the last full backup

## Incremental Backups

### Description
An incremental backup only secures changes since the last backup, regardless of whether it was a full, differential, or incremental backup.

### When to Use
- For frequent backups with minimal resource usage
- When storage space is severely limited
- For scenarios requiring fine granularity of recovery points

### Execution
```bash
mdbackup backup
# Select option 3 for an incremental backup
```

### Technical Details
- Builds on the previous backup (of any type)
- Stores only the most recent changes
- Requires all previous backups in the chain for restoration

## Table-specific Backups

### Description
With a table-specific backup, you can selectively back up specific databases and tables instead of the entire database instance.

### When to Use
- When only certain tables contain critical data
- For very large databases where full backups are impractical
- For special requirements (e.g., development, data extraction)

### Execution
```bash
mdbackup backup
# Select option 4 for a table-specific backup
# Follow the prompts to specify database and tables
```

### Technical Details
- Allows selection of a specific database and specific tables
- Optimizes storage usage and backup time for large databases
- Ideal for data-driven applications with clearly defined critical tables

## Backup Strategies and Recommendations

Here are some recommended backup strategies:

### For Small Databases
- Daily full backups

### For Medium Databases
- Weekly full backup
- Daily differential backups

### For Large Databases
- Weekly full backup
- Daily incremental backups
- Possibly table-specific backups for critical data

## Next Steps

After familiarizing yourself with the different backup types, you should learn about [restoring](Restoration.md) backups and [automating](Automation.md) backup processes.