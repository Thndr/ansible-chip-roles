#!/bin/bash

MARIADB_PASSWORD=$1
POSTACTIV_DB_ADMIN_USER=$2
POSTACTIV_DB_ADMIN_PASSWORD=$3
POSTACTIV_SOCIAL_ADMIN_USER=$4
POSTACTIV_SOCIAL_ADMIN_PASSWORD=$5
POSTACTIV_DOMAIN_NAME=$6

# -----------------------------------------------------------------------------
# Function: install_mariadb
# Installs and configures mariadb on the target system
function install_mariadb {
  export DEBIAN_FRONTEND=noninteractive
  echo "mariadb-server-10.0 mysql-server/root_password password $MARIADB_PASSWORD" | debconf-set-selections
  echo "mmariadb-server-10.0 mysql-server/root_password_again password $MARIADB_PASSWORD" | debconf-set-selections

  #echo "mariadb-server mariadb-server/root_password password $MARIADB_PASSWORD" | debconf-set-selections
  #echo "mariadb-server mariadb-server/root_password_again password $MARIADB_PASSWORD" | debconf-set-selections
  apt-get -yq install mariadb-server

  mysqladmin -u root -p"$MARIADB_PASSWORD" password "$MARIADB_PASSWORD"
}

# -----------------------------------------------------------------------------
# Function: create_postactiv_database
# Set up MariaDB with a database for postActiv
function create_postactiv_database {
    echo "create database postactiv;
CREATE USER '${POSTACTIV_DB_ADMIN_USER}'@'localhost' IDENTIFIED BY '${POSTACTIV_DB_ADMIN_PASSWORD}';
GRANT ALL PRIVILEGES ON postactiv.* TO '${POSTACTIV_DB_ADMIN_USER}'@'localhost';
quit" > ~/batch.sql
    chmod 600 ~/batch.sql
    mysql -u root --password="$MARIADB_PASSWORD" < ~/batch.sql
    shred -zu ~/batch.sql
}

# =============================================================================
function install_postactiv_from_repo {
    chmod +x /var/www/postactiv/scripts/maildaemon.php
    chmod 777 /var/www/postactiv/extlib/HTMLPurifier/HTMLPurifier/DefinitionCache/Serializer.php
    if [ ! grep 'www-data: root' /etc/aliases ]; then
        echo 'www-data: root' >> /etc/aliases
    fi
    if [ ! grep 'maildaemon.php' /etc/aliases ]; then
        echo '*: /var/www/postactiv/scripts/maildaemon.php' >> /etc/aliases
    fi

    # Generate the config
    postactiv_installer=/var/www/postactiv/scripts/install_cli.php
    ${postactiv_installer} --server "${POSTACTIV_DOMAIN_NAME}" \
                           --host="localhost" --database="postactiv" \
                           --dbtype=mysql --username="$POSTACTIV_DB_ADMIN_USER" -v \
                           --password="$POSTACTIV_DB_ADMIN_PASSWORD" \
                           --sitename=$"postactiv" --fancy='yes' \
                           --admin-nick="$POSTACTIV_SOCIAL_ADMIN_USER" \
                           --admin-pass="$POSTACTIV_SOCIAL_ADMIN_PASSWORD" \
                           --site-profile="community" \
                           --ssl="never"

}

# -----------------------------------------------------------------------------
# Function: additional_postactiv_settings
# Adds the additional recommended settings for postactiv to the config file
function additional_postactiv_settings {
    postactiv_config_file=/var/www/postactiv/config.php

    echo "" >> $postactiv_config_file
    echo "// Recommended postactiv settings" >> $postactiv_config_file
    echo "\$config['thumbnail']['maxsize'] = 3000;" >> $postactiv_config_file
    echo "\$config['profile']['delete'] = true;" >> $postactiv_config_file
    echo "\$config['profile']['changenick'] = true;" >> $postactiv_config_file
    echo "\$config['public']['localonly'] = false;" >> $postactiv_config_file
    echo "addPlugin('StoreRemoteMedia');" >> $postactiv_config_file
    echo "\$config['queue']['enabled'] = true;" >> $postactiv_config_file
    echo "\$config['queue']['daemon'] = true;" >> $postactiv_config_file
    echo "\$config['ostatus']['hub_retries'] = 3;" >> $postactiv_config_file

#    # This improves performance
    sed -i "s|//\$config\['db'\]\['schemacheck'\].*|\$config\['db'\]\['schemacheck'\] = 'script';|g" $postactiv_config_file

#    # remove the install script
    if [ -f /var/www/postactiv/install.php ]; then
        rm /var/www/postactiv/install.php
    fi
}

# -----------------------------------------------------------------------------
# Function: Configure Web Server
#

function configure_web_server {
    echo "server {
  listen 80;
  listen [::]:80;
  server_name ${POSTACTIV_DOMAIN_NAME};

  # Logs
  access_log /var/log/nginx/postactiv.access.log;
  error_log /var/log/nginx/postactiv.err.log warn;

  # Root
  root /var/www/postactiv;

  # Index
  index index.php;

  # PHP
  location ~ \.php {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php5-fpm.sock;
  }

  # Location
  location / {
    client_max_body_size 15m;
    client_body_buffer_size 128k;

    try_files \$uri \$uri/ @postactiv;
  }

  # Fancy URLs
  location @postactiv {
    rewrite ^(.*)$ /index.php?p=\$1 last;
  }

  # Restrict access that is unnecessary anyway
  location ~ /\.(ht|git) {
    deny all;
  }
  location /scripts/ {
    deny all;
  }

}" > /etc/nginx/sites-available/postactiv
    ln -s /etc/nginx/sites-available/postactiv /etc/nginx/sites-enabled/

    # Start the web server
    systemctl restart php5-fpm
    systemctl restart nginx
}

# =============================================================================
# -----------------------------------------------------------------------------
# Function: keep_daemons_running
# Sets the system to keep the queue daemons running, and also schedules some
# basic maintenance tasks
function keep_daemons_running {
    echo '#!/bin/bash' > /etc/cron.hourly/postactiv-daemons
    echo -n 'daemon_lines=$(ps aux | grep "' >> /etc/cron.hourly/postactiv-daemons
    echo 'postactiv/scripts/queuedaemon.php" | grep "/var/www")' >> /etc/cron.hourly/postactiv-daemons
    echo 'cd /var/www/postactiv' >> /etc/cron.hourly/postactiv-daemons
    echo 'if [[ $daemon_lines != *"/var/www/"* ]]; then' >> /etc/cron.hourly/postactiv-daemons

    echo '    su -c "sh scripts/startdaemons.sh" -s /bin/sh www-data' >> /etc/cron.hourly/postactiv-daemons
    echo 'fi' >> /etc/cron.hourly/postactiv-daemons

    echo 'php scripts/delete_orphan_files.php > /dev/null' >> /etc/cron.hourly/postactiv-daemons
    echo 'php scripts/clean_thumbnails.php -y > /dev/null' >> /etc/cron.hourly/postactiv-daemons
    echo 'php scripts/clean_file_table.php -y > /dev/null' >> /etc/cron.hourly/postactiv-daemons
    echo 'php scripts/upgrade.php > /dev/null' >> /etc/cron.hourly/postactiv-daemons

    chmod +x /etc/cron.hourly/postactiv-daemons
}

function start_daemons {
        cd /var/www/postactiv
        php scripts/upgrade.php
        su -c "sh scripts/startdaemons.sh" -s /bin/sh www-data
}



# =============================================================================
# Main script logic follows

if [ ! $6 ]; then
    echo './scripts/install_postactiv.sh [mariadb password] [postactiv db admin username] [postactiv db admin password] [postactiv social admin username] [postactiv social admin password] [domain]'
    exit 0
fi

install_mariadb
create_postactiv_database
install_postactiv_from_repo
additional_postactiv_settings
configure_web_server
keep_daemons_running
start_daemons


echo "PostActiv installed"

exit 0

# END OF FILE
# =============================================================================
