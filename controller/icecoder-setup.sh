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
<?php
/*

a:9:{s:13:"loginRequired";b:1;s:18:"enableRegistration";b:0;s:9:"multiUser";b:0;s:8:"demoMode";b:0;s:11:"newDirPerms";i:755;s:12:"newFilePerms";i:644;s:16:"fileDirResOutput";s:4:"none";s:10:"lineEnding";s:1:"
";s:12:"languageBase";s:11:"english.php";}

*/
?>
EOF

cat <<'EOF' > data/config-admin-_.php
<?php
/*

a:44:{s:9:"versionNo";s:3:"8.1";s:16:"configCreateDate";i:1646175146;s:4:"root";s:28:"/../../home/saarctf/checkers";s:12:"checkUpdates";b:0;s:13:"openLastFiles";b:1;s:16:"updateDiffOnSave";b:1;s:12:"languageUser";s:11:"english.php";s:11:"backupsKept";b:0;s:11:"backupsDays";i:0;s:11:"deleteToTmp";b:1;s:16:"findFilesExclude";a:9:{i:0;s:4:".doc";i:1;s:4:".gif";i:2;s:4:".jpg";i:3;s:5:".jpeg";i:4;s:4:".pdf";i:5;s:4:".png";i:6;s:4:".swf";i:7;s:4:".xml";i:8;s:4:".zip";}s:10:"codeAssist";b:1;s:11:"visibleTabs";b:0;s:9:"lockedNav";b:1;s:17:"tagWrapperCommand";s:8:"ctrl+alt";s:12:"autoComplete";s:10:"ctrl+space";s:8:"password";s:<ICECODER_HASH_LEN>:"<ICECODER_HASH>";s:11:"bannedFiles";a:2:{i:0;s:4:".git";i:1;s:12:"node_modules";}s:11:"bannedPaths";a:2:{i:0;s:26:"/var/www/sites/all/modules";i:1;s:28:"/var/www/sites/default/files";}s:10:"allowedIPs";a:1:{i:0;s:1:"*";}s:14:"autoLogoutMins";i:0;s:5:"theme";s:7:"monokai";s:8:"fontSize";s:4:"13px";s:12:"lineWrapping";b:0;s:11:"lineNumbers";b:1;s:17:"showTrailingSpace";b:1;s:13:"matchBrackets";b:1;s:13:"autoCloseTags";b:1;s:17:"autoCloseBrackets";b:1;s:10:"indentType";s:6:"spaces";s:10:"indentAuto";b:1;s:10:"indentSize";i:4;s:18:"pluginPanelAligned";s:4:"left";s:14:"scrollbarStyle";s:7:"overlay";s:21:"selectNextOnFindInput";b:1;s:19:"goToLineScrollSpeed";i:5;s:12:"bugFilePaths";a:1:{i:0;s:27:"//data/logs/error/error.log";}s:17:"bugFileCheckTimer";i:10;s:15:"bugFileMaxLines";i:10;s:7:"plugins";a:0:{}s:15:"tutorialOnLogin";b:0;s:13:"previousFiles";a:0:{}s:11:"last10Files";a:0:{}s:13:"favoritePaths";a:0:{}}

*/
?>
EOF
ICECODER_HASH=$(php -r "echo password_hash('$ICECODER_PASSWORD', PASSWORD_BCRYPT);")
ICECODER_HASH_LEN=${#ICECODER_HASH}
sed -i "s|<ICECODER_HASH>|$ICECODER_HASH|" data/config-admin-_.php
sed -i "s|<ICECODER_HASH_LEN>|$ICECODER_HASH_LEN|" data/config-admin-_.php
ln -s config-admin-_.php data/config-admin-cp_ctf_saarland.php

chown saarctf:saarctf data/*.php

# Patch this shit
sed -i 's|phpversion()|"7.4"|' lib/requirements.php
echo '$ICEcoderDir = "/../../../../../..".$ICEcoderDir;' >> lib/settings.php


PHP_FPM_SOCK=(/var/run/php/*.sock)
cat <<'EOF' > /etc/nginx/sites-available/icecoder
server {
  listen 8082;
  root /opt/icecoder;
  index index.html index.htm index.nginx-debian.html index.php;

  server_name _;

  location / {
    try_files $uri $uri/ =404;
    auth_basic "saarCTF Administration";
    auth_basic_user_file "$SAARCTF_CONFIG_DIR/htpasswd";
  }

  location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:PHP_FPM_SOCK;
    auth_basic "saarCTF Administration";
    auth_basic_user_file "$SAARCTF_CONFIG_DIR/htpasswd";
  }

  location ~ /\.ht {
    deny all;
    auth_basic "saarCTF Administration";
    auth_basic_user_file "$SAARCTF_CONFIG_DIR/htpasswd";
  }
}
EOF
cat <<'EOF' > /etc/nginx/sites-available/icecoder-ssl
server {
  listen 8444 ssl;
  server_name cp.ctf.saarland;
  ssl_certificate /opt/config/certs/fullchain.pem;
  ssl_certificate_key /opt/config/certs/privkey.pem;

  root /opt/icecoder;
  index index.html index.htm index.nginx-debian.html index.php;

  location / {
    try_files $uri $uri/ =404;
    auth_basic "saarCTF Administration";
    auth_basic_user_file "$SAARCTF_CONFIG_DIR/htpasswd";
  }

  location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:PHP_FPM_SOCK;
    auth_basic "saarCTF Administration";
    auth_basic_user_file "$SAARCTF_CONFIG_DIR/htpasswd";
  }

  location ~ /\.ht {
    deny all;
    auth_basic "saarCTF Administration";
    auth_basic_user_file "$SAARCTF_CONFIG_DIR/htpasswd";
  }
}
EOF
sed -i "s|PHP_FPM_SOCK|${PHP_FPM_SOCK[0]}|g" /etc/nginx/sites-available/icecoder
sed -i "s|PHP_FPM_SOCK|${PHP_FPM_SOCK[0]}|g" /etc/nginx/sites-available/icecoder-ssl
sed -i "s|\$SAARCTF_CONFIG_DIR|$SAARCTF_CONFIG_DIR|" /etc/nginx/sites-available/icecoder
sed -i "s|\$SAARCTF_CONFIG_DIR|$SAARCTF_CONFIG_DIR|" /etc/nginx/sites-available/icecoder-ssl
ln -s /etc/nginx/sites-available/icecoder /etc/nginx/sites-enabled/
sed -i 's|^user =.*|user = saarctf|' /etc/php/*/fpm/pool.d/www.conf
sed -i 's|^group =.*|group = saarctf|' /etc/php/*/fpm/pool.d/www.conf
sed -i 's|^;catch_workers_output =.*|catch_workers_output = yes|' /etc/php/*/fpm/pool.d/www.conf
sed -i 's|^;php_admin_value\[error_log\] =.*|php_admin_value[error_log] = /var/log/fpm-php.www.log|' /etc/php/*/fpm/pool.d/www.conf
sed -i 's|^;php_admin_flag\[log_errors\] =.*|php_admin_flag[log_errors] = on|' /etc/php/*/fpm/pool.d/www.conf
touch /var/log/fpm-php.www.log
chown saarctf:saarctf /var/log/fpm-php.www.log
