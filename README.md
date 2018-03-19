# nextcloud

## Preparing a Nextcloud server

From a new EC2 instance from an Ubuntu 16.04 ami

    sudo su -
    apt update
    apt upgrade
    apt install mosh tmux tmuxinator

    cfdisk /dev/xvdb
    # Create a single partition
    mkfs.btrfs --label nextcloud --data single --metadata single /dev/xvdb1 
    
    cd /mnt
    mkdir btrfs
    mount /dev/xvdb1 btrfs
    cd btrfs
    btrfs subvolume create /mnt/btrfs/nc-file-data
    btrfs subvolume create /mnt/btrfs/nc-db-data

## Installing NextCloud and additional software and PHP modules

Install additional packages (software and PHP modules).

    apt-get install apache2 mariadb-server libapache2-mod-php7.0
    apt-get install php7.0-gd php7.0-json php7.0-mysql php7.0-curl php7.0-mbstring
    apt-get install php7.0-intl php7.0-mcrypt php-imagick php7.0-xml php7.0-zip
    apt-get install php7.0-bz2 php7.0-ldap php-smb php7.0-imap
    apt-get install php7.0-gmp php-apcu php-memcached php-redis
    apt-get install ffmpeg libreoffice 

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

## Adjust file ownership and permissions

    cd /var/www
    chown -R www-data:www-data nextcloud
    find nextcloud/ -type d -exec chmod 750 {} \;
    find nextcloud/ -type f -exec chmod 640 {} \;

## Configure Apache

    echo << EOF > /etc/apache2/sites-available/nextcloud.conf
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

    ln -s /etc/apache2/sites-available/nextcloud.conf /etc/apache2/sites-enabled/nextcloud.conf
    EOF

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

    sudo -u www-data echo << EOF > /var/www/nextcloud/config/config.php
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

## Create the MariaDB Database

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

## Run the Nextcloud installer.

    cd /var/www/nextcloud/
    sudo -u www-data php occ  maintenance:install --database "mysql" \
        --database-name "nextcloud"  --database-user "nextcloud" \
        --database-pass "Get-from-lastpass" --admin-user "admin" \
        --admin-pass "Get-from-lastpass"

