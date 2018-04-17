<header>

Nextcloud
=========

</header>
<main>

# Preparing a Nextcloud server

From a Raspberry Pi with Raspian Stretch...

    sudo su -
    apt update
    apt upgrade
    apt install mosh tmux tmuxinator btfs

Setup large capacity disk as the location for the Nextcloud MySQL
database and file data store.

    gdisk /dev/sda
    # Create a partition for root of 16G, a partition for swap of 512M,
    # and a partition for Nextcloud as the rest of the disk.
    # Setup swap as directed in
    # ssjw/new-host-setup/backup-pi-configuration.md

    # Setup encryption as per the same backup-pi-configuration.md.

    mkfs.btrfs --label nextcloud --data single --metadata dup /dev/mapper/enc1
    
    cd /mnt
    mkdir btrfs
    mount dev/mapper/enc1 btrfs
    btrfs subvolume create /mnt/btrfs/nc-file-data
    btrfs subvolume create /mnt/btrfs/nc-db-data
    umount /mnt/btrfs

    echo "/dev/mapper/enc1 /var/lib/mysql btrfs subvol=nc-db-data,noatime,nodatacow 0 1" >> /etc/fstab
    mount /var/lib/mysql
    echo "/dev/mapper/enc1 /var/nextcloud/data btrfs subvol=nc-file-data,noatime,compress=lzo 0 1" >> /etc/fstab
    mount /var/nextcloud/data

# Installing NextCloud and additional software and PHP modules

Install additional packages (software and PHP modules).

    apt-get install apache2 mariadb-server libapache2-mod-php7.0
    apt-get install php7.0-gd php7.0-json php7.0-mysql php7.0-curl php7.0-mbstring
    apt-get install php7.0-intl php7.0-mcrypt php-imagick php7.0-xml php7.0-zip
    # php-smb required php-5.0 packages on Raspbian.  Probably don't
    # need it.
    #apt-get install php7.0-bz2 php7.0-ldap php-smb php7.0-imap
    apt-get install php7.0-bz2 php7.0-ldap php7.0-imap
    apt-get install php7.0-gmp php-apcu php-memcached php-redis
    apt-get install ffmpeg libreoffice 

## Set mariadb and apache2 Not to Start on Boot
They should not be started until the filesystem for Nextcloud data and
Mariadb has been mounted.

    systemctl stop apache2
    systemctl disable apache2
    systemctl stop mariadb
    systemctl disable mariadb

# Install Nextcloud
Download and verify the Nextcloud archive file.

    cd /var/www
    wget https://download.nextcloud.com/server/releases/nextcloud-13.0.1.tar.bz2
    wget https://download.nextcloud.com/server/releases/nextcloud-13.0.1.tar.bz2.sha256
    sha256sum -c nextcloud-13.0.1.tar.bz2.sha256 < nextcloud-13.0.1.tar.bz2
    wget https://download.nextcloud.com/server/releases/nextcloud-13.0.1.tar.bz2.asc
    wget https://nextcloud.com/nextcloud.asc
    gpg --import nextcloud.asc
    gpg --verify nextcloud-13.0.1.tar.bz2.asc nextcloud-13.0.1.tar.bz2

Untar the Nextcloud archive file.

    tar -xjf nextcloud-13.0.1.tar.bz2

# Adjust file ownership and permissions

    cd /var/www
    chown -R www-data:www-data nextcloud
    find nextcloud/ -type d -exec chmod 750 {} \;
    find nextcloud/ -type f -exec chmod 640 {} \;

# Configure Apache

## Setup the Apache Nextcloud virtual host.

    cat - << EOF > /etc/apache2/sites-available/nextcloud.conf
    Alias /nextcloud "/var/www/nextcloud/"

    <Directory /var/www/nextcloud/>
      Options +FollowSymlinks
      AllowOverride All

      <IfModule mod_dav.c>
        Dav off
      </IfModule>

      SetEnv HOME /var/www/nextcloud
      SetEnv HTTP_HOME /var/www/nextcloud

    </Directory>
    EOF

    ln -s /etc/apache2/sites-available/nextcloud.conf /etc/apache2/sites-enabled/nextcloud.conf

## Enable HTTP Strict Transport Security.

From the Nextcloud documentation:

> While redirecting all traffic to HTTPS is good, it may not completely
> prevent man-in-the-middle attacks. Thus administrators are encouraged to
> set the HTTP Strict Transport Security header, which instructs browsers
> to not allow any connection to the Nextcloud instance using HTTP, and it
> attempts to prevent site visitors from bypassing invalid certificate
> warnings.
>
> This can be achieved by setting the following settings within the Apache
> VirtualHost file:
>
>     <VirtualHost *:443>
>       ServerName cloud.nextcloud.com
>       <IfModule mod_headers.c>
>         Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains"
>       </IfModule>
>     </VirtualHost>
>
> **Warning:** We recommend the additional setting `; preload` to be added
> to that header. Then the domain will be added to
> an hardcoded list that is shipped with all major browsers and enforce
> HTTPS upon those domains. See the HSTS preload website for more
> information. Due to the policy of this list you need to add it to the
> above example for yourself once you are sure that this is what you want.
> Removing the domain from this list could take some months until it
> reaches all installed browsers.

## Additional Apache setup

Enable Apache modules.

    a2enmod rewrite
    a2enmod headers
    a2enmod env
    a2enmod dir
    a2enmod mime

Set ServerName for all sites.

    vi /etc/apache2/sites-available/000-default.conf
    # Set ServerName to nextcloud.pigsn.space

Restart Apache.

    service apache2 restart

Configure prettier URLs.

    sudo -u www-data cat - << EOF > /var/www/nextcloud/config/config.php
    <?php

    $CONFIG = array(

    'overwrite.cli.url' => 'https://nextcloud.pigsn.space/nextcloud',
    'htaccess.RewriteBase' => '/nextcloud'

    );

Configure SSL.

    a2enmod ssl
    a2ensite default-ssl
    service apache2 reload

Create a self-signed certificate for now.  Later configure Let's
Encrypt.  From /usr/share/doc/apache2/README.Debian.gz.

First update DNS record for nextcloud.pigsn.space to point to this
virtual machine's IP address, then run the following command.

    make-ssl-cert generate-default-snakeoil --force-overwrite

# Create the MariaDB Database

First update some configuration.

    vi /etc/mysql/mariadb.conf.d/50-server.cnf

    # Add these lines to [mysqld] section.
    # innodb_large_prefix=true
    # innodb_file_format=barracuda
    # innodb_file_per_table=1

Now create the Nextcloud database.

    mysql -uroot -p
    # defaults to empty password on Ubuntu.
    CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY 'Get-from-lastpass';
    CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost' IDENTIFIED BY 'Get-from-lastpass';
    quit

# Run the Nextcloud installer.
> **TODO**: Figure out how to configure the Nextcloud data directory
> during this installation step.

    cd /var/www/nextcloud/
    sudo -u www-data php occ  maintenance:install --database "mysql" \
        --database-name "nextcloud"  --database-user "nextcloud" \
        --database-pass "Get-from-lastpass" --admin-user "admin" \
        --admin-pass "Get-from-lastpass"

# Visit the new Nextcloud site.

Point browser to https://hostname/nextcloud/

The "/" at the end is significant.  I will need to investigate whether
there is some configuration such that you can get the Nextcloud site
with or without the trailing slash.

# Additional Setup

[ ] Enable encryption
[ ] Enable External Storages app

</main>
