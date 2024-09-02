#!/bin/bash

set -e

source /etc/profile.d/env.sh

export DEBIAN_FRONTEND=noninteractive

# git clone https://github.com/mattpass/ICEcoder.git /opt/icecoder
# apt-get install -y unzip
cd /opt
#wget https://icecoder.net/download-zip -O /tmp/icecoder.zip
wget https://github.com/icecoder/ICEcoder/archive/8.1.zip -O /tmp/icecoder.zip
unzip /tmp/icecoder.zip
mv ICE* icecoder
cd /opt/icecoder
mkdir -p backups
chmod 757 backups tmp
chown saarctf:saarctf data

cat <<'EOF' > data/config-global.php
>>>>>>> copy: icecoder/data/config-global.php <<<<<<<<
EOF

cat <<'EOF' > data/config-admin-_.php
>>>>>>> copy: icecoder/data/config-admin-_.php <<<<<<<<
EOF


# Good luck, lol
>>>>>>>>>> set icecoder_hash fact and handle with templating <<<<
ICECODER_HASH=$(php -r "echo password_hash('$ICECODER_PASSWORD', PASSWORD_BCRYPT);")


>>>>>>> template: icecoder/data/config-admin-_.php.j2 <<<<<<<<
>>>>>>> template: icecoder/data/config-global.php.j2 <<<<<<<<

ln -s config-admin-_.php data/config-admin-cp_ctf_saarland.php

chown saarctf:saarctf data/*.php

# Patch this shit
sed -i 's|phpversion()|"7.4"|' lib/requirements.php
echo '$ICEcoderDir = "/../../../../../..".$ICEcoderDir;' >> lib/settings.php


>>>>>>>>>> set php_fpm_sock fact and handle with templating <<<<
PHP_FPM_SOCK=(/var/run/php/*.sock)


>>>>>>> template: nginx/sites-available/icecoder.j2 <<<<<<<<


ln -s /etc/nginx/sites-available/icecoder /etc/nginx/sites-enabled/


>>>>>>> template: nginx/sites-available/icecoder-ssl.j2 <<<<<<<<




sed -i 's|^user =.*|user = saarctf|' /etc/php/*/fpm/pool.d/www.conf
sed -i 's|^group =.*|group = saarctf|' /etc/php/*/fpm/pool.d/www.conf
sed -i 's|^;catch_workers_output =.*|catch_workers_output = yes|' /etc/php/*/fpm/pool.d/www.conf
sed -i 's|^;php_admin_value\[error_log\] =.*|php_admin_value[error_log] = /var/log/fpm-php.www.log|' /etc/php/*/fpm/pool.d/www.conf
sed -i 's|^;php_admin_flag\[log_errors\] =.*|php_admin_flag[log_errors] = on|' /etc/php/*/fpm/pool.d/www.conf
touch /var/log/fpm-php.www.log
chown saarctf:saarctf /var/log/fpm-php.www.log
