#!/bin/bash

MARIADB_PASSWORD=$1
POSTACTIV_DB_ADMIN_USER=$2
POSTACTIV_DB_ADMIN_PASSWORD=$3
POSTACTIV_SOCIAL_ADMIN_USER=$4
POSTACTIV_SOCIAL_ADMIN_PASSWORD=$5
POSTACTIV_DOMAIN_NAME=$6
MY_EMAIL_ADDRESS=$7

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
                           --ssl="always"

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
# Function: Install TLS Certs


function configure_tls_cert {
    # Diffie-Hellman parameters. From BetterCrypto:
    #
    #   "Where configurable, we recommend using the Diffie Hellman groups
    #    defined for IKE, specifically groups 14-18 (2048 ^ ^ 8192bit MODP).
    #    These groups have been checked by many eyes and can be assumed
    #    to be secure."
    echo '-----BEGIN DH PARAMETERS-----
MIIECAKCBAEA///////////JD9qiIWjCNMTGYouA3BzRKQJOCIpnzHQCC76mOxOb
IlFKCHmONATd75UZs806QxswKwpt8l8UN0/hNW1tUcJF5IW1dmJefsb0TELppjft
awv/XLb0Brft7jhr+1qJn6WunyQRfEsf5kkoZlHs5Fs9wgB8uKFjvwWY2kg2HFXT
mmkWP6j9JM9fg2VdI9yjrZYcYvNWIIVSu57VKQdwlpZtZww1Tkq8mATxdGwIyhgh
fDKQXkYuNs474553LBgOhgObJ4Oi7Aeij7XFXfBvTFLJ3ivL9pVYFxg5lUl86pVq
5RXSJhiY+gUQFXKOWoqqxC2tMxcNBFB6M6hVIavfHLpk7PuFBFjb7wqK6nFXXQYM
fbOXD4Wm4eTHq/WujNsJM9cejJTgSiVhnc7j0iYa0u5r8S/6BtmKCGTYdgJzPshq
ZFIfKxgXeyAMu+EXV3phXWx3CYjAutlG4gjiT6B05asxQ9tb/OD9EI5LgtEgqSEI
ARpyPBKnh+bXiHGaEL26WyaZwycYavTiPBqUaDS2FQvaJYPpyirUTOjbu8LbBN6O
+S6O/BQfvsqmKHxZR05rwF2ZspZPoJDDoiM7oYZRW+ftH2EpcM7i16+4G912IXBI
HNAGkSfVsFqpk7TqmI2P3cGG/7fckKbAj030Nck0AoSSNsP6tNJ8cCbB1NyyYCZG
3sl1HnY9uje9+P+UBq2eUw7l2zgvQTABrrBqU+2QJ9gxF5cnsIZaiRjaPtvrz5sU
7UTObLrO1Lsb238UR+bMJUszIFFRK9evQm+49AE3jNK/WYPKAcZLkuzwMuoV0XId
A/SC185udP721V5wL0aYDIK1qEAxkAscnlnnyX++x+jzI6l6fjbMiL4PHUW3/1ha
xUvUB7IrQVSqzI9tfr9I4dgUzF7SD4A34KeXFe7ym+MoBqHVi7fF2nb1UKo9ih+/
8OsZzLGjE9Vc2lbJ7C7yljI4f+jXbjwEaAQ+j2Y/SGDuEr8tWwt0dNbmlPkebb4R
WXSjkm8S/uXkOHd8tqky34zYvsTQc7kxujvIMraNndMAdB+nv4r8R+0ldvaTa6Qk
ZjqrY5xa5PVoNCO0dCvxyXgjjxbL451lLeP9uL78hIrZIiIuBKQDfAcT61eoGiPw
xzRz/GRs6jBrS8vIhi+Dhd36nUt/osCH6HloMwPtW906Bis89bOieKZtKhP4P0T4
Ld8xDuB0q2o2RZfomaAlXcFk8xzFCEaFHfmrSBld7X6hsdUQvX7nTXP682vDHs+i
aDWQRvTrh5+SQAlDi0gcbNeImgAu1e44K8kZDab8Am5HlVjkR1Z36aqeMFDidlaU
38gfVuiAuW5xYMmA3Zjt09///////////wIBAg==
-----END DH PARAMETERS-----
' > /etc/ssl/certs/${POSTACTIV_DOMAIN_NAME}.dhparam

    # Get a LetsEncrypt cert
       apt-get -yq install certbot -t jessie-backports
    systemctl stop nginx
    if [ ! -f /etc/letsencrypt/live/${POSTACTIV_DOMAIN_NAME}/fullchain.pem ]; then
        certbot certonly -n --server https://acme-v01.api.letsencrypt.org/directory --standalone -d $POSTACTIV_DOMAIN_NAME --renew-by-default --agree-tos --email $MY_EMAIL_ADDRESS
        ln -s /etc/letsencrypt/live/${POSTACTIV_DOMAIN_NAME}/privkey.pem /etc/ssl/private/${POSTACTIV_DOMAIN_NAME}.key
        ln -s /etc/letsencrypt/live/${POSTACTIV_DOMAIN_NAME}/fullchain.pem /etc/ssl/certs/${POSTACTIV_DOMAIN_NAME}.pem
    fi

    # LetsEncrypt cert renewals
    renewals_script=/etc/cron.monthly/letsencrypt
    renewals_retry_script=/etc/cron.daily/letsencrypt

    # the main script tries to renew once per month
    echo '#!/bin/bash' > $renewals_script
    echo 'if [ -d /etc/letsencrypt ]; then' >> $renewals_script
    echo '    if [ -f ~/letsencrypt_failed ]; then' >> $renewals_script
    echo '        rm ~/letsencrypt_failed' >> $renewals_script
    echo '    fi' >> $renewals_script
    echo '    for d in /etc/letsencrypt/live/*/ ; do' >> $renewals_script
    echo -n '        LETSENCRYPT_DOMAIN=$(echo "$d" | ' >> $renewals_script
    echo -n "awk -F '/' '{print " >> $renewals_script
    echo -n '$5' >> $renewals_script
    echo "}')" >> $renewals_script
    echo '        if [ -f /etc/nginx/sites-available/$LETSENCRYPT_DOMAIN ]; then' >> $renewals_script
    echo "            certbot certonly -n --server https://acme-v01.api.letsencrypt.org/directory --standalone -d \$LETSENCRYPT_DOMAIN --renew-by-default --agree-tos --email $MY_EMAIL_ADDRESS" >> $renewals_script
    echo '            if [ ! "$?" = "0" ]; then' >> $renewals_script
    echo "                echo \"The certificate for \$LETSENCRYPT_DOMAIN could not be renewed\" > ~/temp_renewletsencrypt.txt" >> $renewals_script
    echo '                echo "" >> ~/temp_renewletsencrypt.txt' >> $renewals_script
    echo "                certbot certonly -n --server https://acme-v01.api.letsencrypt.org/directory --standalone -d \$LETSENCRYPT_DOMAIN --renew-by-default --agree-tos --email $MY_EMAIL_ADDRESS 2>> ~/temp_renewletsencrypt.txt" >> $ren$
    echo "                cat ~/temp_renewletsencrypt.txt | mail -s \"postActiv Lets Encrypt certificate renewal\" $MY_EMAIL_ADDRESS" >> $renewals_script
    echo '                rm ~/temp_renewletsencrypt.txt' >> $renewals_script
    echo '                if [ ! -f ~/letsencrypt_failed ]; then' >> $renewals_script
    echo '                    touch ~/letsencrypt_failed' >> $renewals_script
    echo '                fi' >> $renewals_script
    echo '            fi' >> $renewals_script
    echo '        fi' >> $renewals_script
    echo '    done' >> $renewals_script
    echo 'fi' >> $renewals_script
    chmod +x $renewals_script

    # a secondary script keeps trying to renew after a failure
    echo '#!/bin/bash' > $renewals_retry_script
    echo '' >> $renewals_retry_script
    echo 'if [ -d /etc/letsencrypt ]; then' >> $renewals_retry_script
    echo '    if [ -f ~/letsencrypt_failed ]; then' >> $renewals_retry_script
    echo '        rm ~/letsencrypt_failed' >> $renewals_retry_script
    echo '        for d in /etc/letsencrypt/live/*/ ; do' >> $renewals_retry_script
    echo -n '            LETSENCRYPT_DOMAIN=$(echo "$d" | ' >> $renewals_retry_script
    echo -n "awk -F '/' '{print " >> $renewals_retry_script
    echo -n '$5' >> $renewals_retry_script
    echo "}')" >> $renewals_retry_script
    echo '            if [ -f /etc/nginx/sites-available/$LETSENCRYPT_DOMAIN ]; then' >> $renewals_retry_script
    echo "                certbot certonly -n --server https://acme-v01.api.letsencrypt.org/directory --standalone -d \$LETSENCRYPT_DOMAIN --renew-by-default --agree-tos --email $MY_EMAIL_ADDRESS" >> $renewals_retry_script
    echo '                if [ ! "$?" = "0" ]; then' >> $renewals_retry_script
    echo "                    echo \"The certificate for \$LETSENCRYPT_DOMAIN could not be renewed\" > ~/temp_renewletsencrypt.txt" >> $renewals_retry_script
    echo '                    echo "" >> ~/temp_renewletsencrypt.txt' >> $renewals_retry_script
    echo "                    certbot certonly -n --server https://acme-v01.api.letsencrypt.org/directory --standalone -d \$LETSENCRYPT_DOMAIN --renew-by-default --agree-tos --email $MY_EMAIL_ADDRESS 2>> ~/temp_renewletsencrypt.txt" >> $
    echo "                    cat ~/temp_renewletsencrypt.txt | mail -s \"postActiv Lets Encrypt certificate renewal\" $MY_EMAIL_ADDRESS" >> $renewals_retry_script
    echo '                    rm ~/temp_renewletsencrypt.txt' >> $renewals_retry_script
    echo '                    if [ ! -f ~/letsencrypt_failed ]; then' >> $renewals_retry_script
    echo '                        touch ~/letsencrypt_failed' >> $renewals_retry_script
    echo '                    fi' >> $renewals_retry_script
    echo '                fi' >> $renewals_retry_script
    echo '            fi' >> $renewals_retry_script
    echo '        done' >> $renewals_retry_script
    echo '    fi' >> $renewals_retry_script
    echo 'fi' >> $renewals_retry_script
    chmod +x $renewals_retry_script
}

# -----------------------------------------------------------------------------
# Function: Configure Web Server
#

function configure_web_server {

    echo "server {
  listen 80;
  listen [::]:80;
  server_name ${POSTACTIV_DOMAIN_NAME};
  root /var/www/postactiv;
  access_log /var/log/nginx/postactiv.access.log;
  error_log /var/log/nginx/postactiv.err.log warn;
  client_max_body_size 20m;
  client_body_buffer_size 128k;

  rewrite ^ https://$server_name\$request_uri? permanent;
}

server {
  listen 443 ssl;
  listen [::]:443 ssl;
  server_name ${POSTACTIV_DOMAIN_NAME};

  gzip            on;
  gzip_min_length 1000;
  gzip_proxied    expired no-cache no-store private auth;
  gzip_types      text/plain application/xml;

  ssl on;
  ssl_stapling on;
  ssl_stapling_verify on;
  ssl_certificate /etc/ssl/certs/${POSTACTIV_DOMAIN_NAME}.pem;
  ssl_certificate_key /etc/ssl/private/${POSTACTIV_DOMAIN_NAME}.key;
  ssl_dhparam /etc/ssl/certs/${POSTACTIV_DOMAIN_NAME}.dhparam;

  ssl_session_cache  builtin:1000  shared:SSL:10m;
  ssl_session_timeout 60m;
  ssl_prefer_server_ciphers on;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_ciphers 'EDH+CAMELLIA:EDH+aRSA:EECDH+aRSA+AESGCM:EECDH+aRSA+SHA256:EECDH:+CAMELLIA128:+AES128:+SSLv3:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!DSS:!RC4:!SEED:!IDEA:!ECDSA:kEDH:CAMELLIA128-SHA:AES128-SHA';
  add_header Content-Security-Policy \"default-src https:; script-src https: 'unsafe-inline'; style-src https: 'unsafe-inline'\";
  add_header X-Frame-Options DENY;
  add_header X-Content-Type-Options nosniff;

  add_header Strict-Transport-Security max-age=15768000;


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

if [ ! $7 ]; then
    echo './scripts/install_postactiv.sh [mariadb password] [postactiv db admin username] [postactiv db admin password] [postactiv social admin username] [postactiv social admin password] [domain] [email]'
    exit 0
fi

install_mariadb
create_postactiv_database
install_postactiv_from_repo
additional_postactiv_settings
configure_tls_cert
configure_web_server
keep_daemons_running
start_daemons


echo "PostActiv installed"

exit 0

# END OF FILE
# =============================================================================
