#! /bin/bash

# Turn on maintenance mode to lock the sessions of logged in users and
# prevent new logins.
sudo -u www-data php occ maintenance:mode --on

# Create a readonly snapshot of the Nextcloud data directory.
btrfs subvolume snapshot -r /var/nextcloud /var/nextcloud/nc-backup  

# Rsync Nextcloud config directory to a local backup directory.
rsync -ax /var/www/nextcloud/config /var/nextcloud/nc-config-bkp/

# Rsync Nextcloud themes directory to a local backup directory.
rsync -ax /var/www/nextcloud/themes /var/nextcloud/nc-config-bkp/

# Export database to local directory.
mysqldump --single-transaction nextcloud > /var/nextcloud/nc-sqlbkp_`date +"%Y%m%d"`.bak

# rsync all to backup Nextcloud server.


# Backup server will be backed up to remote storage.
