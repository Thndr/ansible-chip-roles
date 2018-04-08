#!/bin/bash

MARIADB_PASSWORD=$1
DB_NAME=$2
DB_ADMIN_USER=$3
DB_ADMIN_PASSWORD=$4

# -----------------------------------------------------------------------------
# Function: install_mariadb
# Installs and configures mariadb on the target system
function install_mariadb {
  export DEBIAN_FRONTEND=noninteractive
  echo "mariadb-server-10.0 mysql-server/root_password password $MARIADB_PASSWORD" | debconf-set-selections
  echo "mariadb-server-10.0 mysql-server/root_password_again password $MARIADB_PASSWORD" | debconf-set-selections

  #echo "mariadb-server mariadb-server/root_password password $MARIADB_PASSWORD" | debconf-set-selections
  #echo "mariadb-server mariadb-server/root_password_again password $MARIADB_PASSWORD" | debconf-set-selections
  apt-get -yq install mariadb-server

  mysqladmin -u root -p"$MARIADB_PASSWORD" password "$MARIADB_PASSWORD"
}

# -----------------------------------------------------------------------------
# Function: create_hubzillla_database
# Set up MariaDB with a database for hubzilla
function create_hubzillla_database {
    echo "create database ${DB_NAME};
CREATE USER ${DB_ADMIN_USER}@'localhost' IDENTIFIED BY '${DB_ADMIN_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${DB_ADMIN_USER}@'localhost';
quit" > ~/batch.sql
    chmod 600 ~/batch.sql
    mysql -u root --password="$MARIADB_PASSWORD" < ~/batch.sql
    shred -zu ~/batch.sql
}

# =============================================================================

if [ ! $4 ]; then
    echo './scripts/install_mariadb.sh [mariadb password] [db admin username] [db admin password]'
    exit 0
fi

install_mariadb
create_hubzillla_database

echo "MariDB installed"

exit 0

# END OF FILE
# =============================================================================

