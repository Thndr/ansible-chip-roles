#!/bin/bash

MARIADB_PASSWORD=$1
GNUFM_DB_ADMIN_USER=$2
GNUFM_DB_ADMIN_PASSWORD=$3


# -----------------------------------------------------------------------------
# Function: create_gnufm_database
# Set up MariaDB with a database for gnufm
function create_gnufm_database {
    echo "create database gnufm;
CREATE USER '${GNUFM_DB_ADMIN_USER}'@'localhost' IDENTIFIED BY '${GNUFM_DB_ADMIN_PASSWORD}';
GRANT ALL PRIVILEGES ON gnufm.* TO '${GNUFM_DB_ADMIN_USER}'@'localhost';
quit" > ~/batch.sql
    chmod 600 ~/batch.sql
    mysql -u root --password="$MARIADB_PASSWORD" < ~/batch.sql
    shred -zu ~/batch.sql
}


function composer_installs {
chown www-data:www-data -R /var/www/gnufm
chown www-data:www-data -R /var/www/gnukebox

cd /var/www/gnukebox/
composer install
cd /var/www/gnufm/
composer install
}


# =============================================================================
# Main script logic follows

if [ ! $3 ]; then
    echo './scripts/install_postactiv.sh [mariadb password] [gnufm db admin username] [gnufm db admin password]'
    exit 0
fi

create_gnufm_database
composer_installs

echo "GNUFM installed"

exit 0

# END OF FILE
# =============================================================================

