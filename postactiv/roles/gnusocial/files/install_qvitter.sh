#!/bin/bash
config_file=/var/www/postactiv/config.php
config_line="addPlugin('Qvitter')"

#if [ ! grep -q "addPlugin('Qvitter')" $config_file ]; then


if grep -qw $config_line $config_file; then
    echo "Qvitter already installed"
else
    echo "" >> $config_file
    echo "// Qvitter settings" >> $config_file
    echo "addPlugin('Qvitter');" >> $config_file
    echo "\$config['site']['qvitter']['enabledbydefault'] = true;" >> $config_file
    echo "\$config['site']['qvitter']['defaultbackgroundcolor'] = '#f4f4f4';" >> $config_file
    echo "\$config['site']['qvitter']['defaultlinkcolor'] = '#0084B4';" >> $config_file
    echo "\$config['site']['qvitter']['timebetweenpolling'] = 30000; // 30 secs" >> $config_file
    echo "\$config['site']['qvitter']['favicon'] = 'img/favicon.ico?v=4';" >> $config_file
    echo "\$config['site']['qvitter']['sprite'] = Plugin::staticPath('Qvitter', '').'img/sprite.png?v=40';" >> $config_file
    echo "\$config['site']['qvitter']['enablewelcometext'] = false;" >> $config_file
    echo "\$config['site']['qvitter']['blocked_ips'] = array();" >> $config_file
fi
cd /var/www/postactiv
php scripts/upgrade.php
php scripts/checkschema.php

