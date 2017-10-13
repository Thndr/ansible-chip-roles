#!/bin/bash

cd /tmp/gnufm/
cp -r /tmp/gnufm/nixtape/* /var/www/gnufm/
cp -r /tmp/gnufm/gnukebox/* /var/www/gnukebox/
cp -r /tmp/librefm/nixtape/* /var/www/gnufm/
cp -r /tmp/librefm/gnukebox/* /var/www/gnukebox/
chown www-data:www-data -R /var/www/gnufm
chown www-data:www-data -R /var/www/gnukebox

