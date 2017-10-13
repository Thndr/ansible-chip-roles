#!/bin/bash

TLS_DOMAIN_NAME=$1
MY_EMAIL_ADDRESS=$2

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
' > /etc/ssl/certs/${TLS_DOMAIN_NAME}.dhparam

    # Get a LetsEncrypt cert
       apt-get -yq install certbot -t jessie-backports
    systemctl stop nginx
    if [ ! -f /etc/letsencrypt/live/${TLS_DOMAIN_NAME}/fullchain.pem ]; then
        certbot certonly -n --server https://acme-v01.api.letsencrypt.org/directory --standalone -d $TLS_DOMAIN_NAME --renew-by-default --agree-tos --email $MY_EMAIL_ADDRESS
        ln -s /etc/letsencrypt/live/${TLS_DOMAIN_NAME}/privkey.pem /etc/ssl/private/${TLS_DOMAIN_NAME}.key
        ln -s /etc/letsencrypt/live/${TLS_DOMAIN_NAME}/fullchain.pem /etc/ssl/certs/${TLS_DOMAIN_NAME}.pem
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

    systemctl restart php5-fpm
    systemctl restart nginx
}

# =============================================================================
# Main script logic follows

if [ ! $2 ]; then
    echo './scripts/install_tls_certs.sh [domain] [email]'
    exit 0
fi

configure_tls_cert


echo "Certs installed"

exit 0

# END OF FILE
# =============================================================================
