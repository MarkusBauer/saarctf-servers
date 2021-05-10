#!/bin/bash

set -e

source /etc/profile.d/env.sh

export DEBIAN_FRONTEND=noninteractive

# git clone https://github.com/mattpass/ICEcoder.git /opt/icecoder
apt-get install -y unzip
cd /opt
#wget https://icecoder.net/download-zip -O /tmp/icecoder.zip
wget https://github.com/icecoder/ICEcoder/archive/7.0.zip -O /tmp/icecoder.zip
unzip /tmp/icecoder.zip
mv ICE* icecoder
cd /opt/icecoder
mkdir -p backups
chmod 757 backups tmp
chown saarctf:saarctf data

cat <<'EOF' > data/config-settings.php
<?php
// ICEcoder system settings
$ICEcoderSettings = array(
        "versionNo"             => "7.0",
        "codeMirrorDir"         => "CodeMirror",
        "docRoot"               => "/home/saarctf/checkers",   // Set absolute path of another location if needed
        "demoMode"              => false,
        "devMode"               => false,
        "fileDirResOutput"      => "none",                      // Can be none, raw, object, both (all but 'none' output to console)
        "loginRequired"         => false,
        "multiUser"             => false,
        "languageBase"          => "english.php",
        "lineEnding"            => "\n",
        "newDirPerms"           => 755,
        "newFilePerms"          => 644,
        "enableRegistration"    => false
);
$_SERVER['SERVER_NAME'] = 'x';
EOF

cat <<'EOF' > data/config-x.php
<?php
$ICEcoderUserSettings = array(
"versionNo"             => "7.0",
"licenseEmail"          => "v7free@icecoder.net",
"licenseCode"           => "93be18fba1dee0e186031907422a0f8df3462568bfd0161e1504",
"configCreateDate"      => 1573226573,
"root"                  => "",
"checkUpdates"          => false,
"openLastFiles"         => true,
"updateDiffOnSave"      => true,
"languageUser"          => "english.php",
"backupsKept"           => true,
"backupsDays"           => 14,
"deleteToTmp"           => true,
"findFilesExclude"      => array(".doc",".gif",".jpg",".jpeg",".pdf",".png",".swf",".xml",".zip"),
"codeAssist"            => true,
"visibleTabs"           => false,
"lockedNav"             => true,
"tagWrapperCommand"     => "ctrl+alt",
"autoComplete"          => "ctrl+space",
"password"              => '<ICECODER_HASH>',
"bannedFiles"           => array(),
"bannedPaths"           => array("/var/www/.git","/var/www/sites/all/modules","/var/www/sites/default/files"),
"allowedIPs"            => array("*"),
"autoLogoutMins"        => 0,
"theme"                 => "monokai",
"fontSize"              => "13px",
"lineWrapping"          => false,
"lineNumbers"           => true,
"showTrailingSpace"     => true,
"matchBrackets"         => true,
"autoCloseTags"         => true,
"autoCloseBrackets"     => true,
"indentWithTabs"        => false,
"indentAuto"            => true,
"indentSize"            => 4,
"pluginPanelAligned"    => "left",
"bugFilePaths"<TAB><TAB>=> array(),
"bugFileCheckTimer"     => 0,
"bugFileMaxLines"       => 0,
"githubAuthToken"       => "",
"plugins"               => array(),
"ftpSites"<TAB><TAB>=> array(),
"githubLocalPaths"<TAB><TAB>=> array(),
"githubRemotePaths"<TAB><TAB>=> array(),
"previousFiles"<TAB><TAB>=> "",
"last10Files"<TAB><TAB>=> "",
"favoritePaths"<TAB><TAB>=> array()
);
EOF
ICECODER_HASH=$(php -r "echo password_hash('$ICECODER_PASSWORD', PASSWORD_BCRYPT);")
sed -i "s|<ICECODER_HASH>|$ICECODER_HASH|" data/config-x.php
sed -i "s|<TAB>|`echo -en \"\t\"`|g" data/config-x.php

chown saarctf:saarctf data/*.php

# Patch this shit
sed -i 's|phpversion()|"7.3"|' lib/requirements.php
echo '$ICEcoderDir = "/../../../../../..".$ICEcoderDir;' >> lib/settings.php


PHP_FPM_SOCK=`echo /var/run/php/*.sock`
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
  listen 8444;
  server_name cp.ctf.saarland;
  ssl on;
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
sed -i "s|PHP_FPM_SOCK|$PHP_FPM_SOCK|g" /etc/nginx/sites-available/icecoder
sed -i "s|PHP_FPM_SOCK|$PHP_FPM_SOCK|g" /etc/nginx/sites-available/icecoder-ssl
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
