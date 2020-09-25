#!/usr/bin/env bash

# =============================
# = saarCTF Controller server =
# =============================

set -e

is_virtualbox() {
  (dmidecode -t system|grep 'Manufacturer\|Product' | grep -q 'VirtualBox')
  return $?
}

is_hetzner() {
  (dmidecode -t system|grep 'Manufacturer\|Product' | grep -q 'Hetzner')
  return $?
}


source /etc/profile.d/env.sh
git -C /opt/config pull


sed -i 's|-base|-controller|g' /etc/hostname
sed -i 's|-base|-controller|g' /etc/hosts
hostname saarctf-controller

echo -e '\n=== saarCTF Gameserver Controller ===\n' > /etc/motd


# Virtualbox only - configure IP on second interface
is_virtualbox && (
    echo 'allow-hotplug enp0s8' > /etc/network/interfaces.d/vboxnet
    echo 'iface enp0s8 inet static' >> /etc/network/interfaces.d/vboxnet
    echo '    address 10.32.250.2/16' >> /etc/network/interfaces.d/vboxnet
    echo '    up ip route add 10.32.0.0/17 via 10.32.250.1' >> /etc/network/interfaces.d/vboxnet
    echo '    up ip route add 10.32.128.0/18 via 10.32.250.1' >> /etc/network/interfaces.d/vboxnet
    echo '    up ip route add 10.32.192.0/19 via 10.32.250.1' >> /etc/network/interfaces.d/vboxnet
    echo '    up ip route add 10.33.0.0/16 via 10.32.250.1' >> /etc/network/interfaces.d/vboxnet
    echo '    up ip route add 10.48.16.0/15 via 10.32.250.1' >> /etc/network/interfaces.d/vboxnet
) || true

is_hetzner && (
    # ens10 = internal network adapter, enp7s0 = on CPX servers
    iptables -A INPUT -i ens10 -j ACCEPT -m comment --comment "Internal network"
    iptables -A INPUT -i enp7s0 -j ACCEPT -m comment --comment "Internal network"
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT -m comment --comment "SSH"
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT -m comment --comment "HTTP / Scoreboard"
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT -m comment --comment "HTTPS / Scoreboard + CP"
    iptables -A INPUT -p tcp --dport 3000 -j ACCEPT -m comment --comment "HTTP / Grafana"
    iptables -A INPUT -p tcp --dport 8080 -j ACCEPT -m comment --comment "HTTP / CP"
    iptables -A INPUT -p tcp --dport 8443 -j ACCEPT -m comment --comment "HTTPS / Flower"
    iptables -A INPUT -p tcp --dport 8444 -j ACCEPT -m comment --comment "HTTPS / IceCoder"
    iptables -A INPUT -p tcp --dport 8445 -j ACCEPT -m comment --comment "HTTPS / Grafana"
    # these ports work only over internal network
    #iptables -A INPUT -p tcp --dport 8081 -j ACCEPT -m comment --comment "HTTP / Flower"
    #iptables -A INPUT -p tcp --dport 8082 -j ACCEPT -m comment --comment "HTTP / IceCoder"
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -P INPUT DROP

    ip6tables -A INPUT -i ens10 -j ACCEPT
    ip6tables -A INPUT -i enp7s0 -j ACCEPT
    ip6tables -P INPUT DROP

    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
) || true


export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y
apt-get install -y \
    postgresql \
    redis-server \
    rabbitmq-server \
    build-essential g++ cmake \
    libev-dev libhiredis-dev libpq-dev libssl-dev postgresql-server-dev-11 \
    uwsgi uwsgi-plugin-gevent-python3 uwsgi-plugin-python3 \
    nodejs npm \
    nginx apache2-utils php-fpm \
    software-properties-common socat
apt-get clean


# Make user
useradd saarctf -m -U -s "/bin/bash"
echo 'source /etc/profile.d/env.sh' >> /home/saarctf/.profile
echo 'source /etc/profile.d/env.sh' >> /home/saarctf/.bashrc
mkdir -p /home/saarctf/checkers /home/saarctf/.ssh
cp /root/.ssh/id_rsa* /home/saarctf/.ssh/
chown -R saarctf:saarctf /home/saarctf/checkers /home/saarctf/.ssh
cd /
sudo -u saarctf -H git config --global user.name "saarctf server"
sudo -u saarctf -H git config --global user.email "saarctf@saarsec.rocks"


# Configure PostgreSQL and setup database
cd /etc/postgresql/*/main
#sed -i 's|max_connections = \d+|max_connections = 500|' postgresql.conf
echo 'max_connections = 500' >> conf.d/saarctf.conf
echo "listen_addresses = '*'" >> conf.d/saarctf.conf
sed -i 's/local  *all  *all  *peer//' pg_hba.conf
echo 'local all all md5' >> pg_hba.conf
echo 'host all all all md5' >> pg_hba.conf


# Configure replication
mkdir -p /root/failover
echo 'host replication replicator all md5' >> pg_hba.conf
echo 'wal_level = replica' >> conf.d/replication.conf
echo 'archive_mode = on' >> conf.d/replication.conf
echo "archive_command = 'test ! -f /srv/pg_archive/%f && cp %p /srv/pg_archive/%f'" >> conf.d/replication.conf
echo 'wal_log_hints = on' >> conf.d/replication.conf
echo 'max_wal_senders = 3' >> conf.d/replication.conf
echo 'hot_standby = on' >> conf.d/replication.conf
mkdir -p /srv/pg_archive
chown postgres /srv/pg_archive
chmod o-rx /srv/pg_archive
systemctl restart postgresql

PG_SERVER=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres server`
PG_USERNAME=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres username`
PG_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres password`
PG_DATABASE=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres database`


cat <<EOF > /root/failover/recovery.conf
standby_mode = 'on'
recovery_target_timeline = 'latest'
primary_conninfo = 'host=$PG_SERVER port=5432 user=replicator password=$PG_REPLICATION_PASSWORD'
# restore_command = 'cp /srv/pg_archive/%f %p'
# archive_cleanup_command = 'pg_archivecleanup /srv/pg_archive %r'
EOF

cat <<EOF | sudo -u postgres psql
CREATE USER $PG_USERNAME WITH PASSWORD '$PG_PASSWORD';
CREATE DATABASE $PG_DATABASE WITH OWNER=$PG_USERNAME;
CREATE USER replicator WITH REPLICATION LOGIN PASSWORD '$PG_REPLICATION_PASSWORD';
\\c $PG_DATABASE
EOF
systemctl restart postgresql

# This machine can use the postgresql socket - disabled for now (too complex)
# echo 'SAARCTF_POSTGRES_USE_SOCKET=True' >> /etc/environment
# echo 'export SAARCTF_POSTGRES_USE_SOCKET=True' >> /etc/profile.d/env.sh

sed -i "s|__REPLACE_PG_REPLICATION_PASSWORD__|$PG_REPLICATION_PASSWORD|" /root/failover-set-slave.sh


# Configure Redis
REDIS_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases redis password`
sed -i 's|^bind .*|bind 0.0.0.0|' /etc/redis/redis.conf
sed -i "/# requirepass.*/a requirepass $REDIS_PASSWORD" /etc/redis/redis.conf
systemctl restart redis


# Configure RabbitMQ
MQ_VHOST=`python3 /opt/gameserver/saarctf_commons/config.py get databases rabbitmq vhost`
MQ_USERNAME=`python3 /opt/gameserver/saarctf_commons/config.py get databases rabbitmq username`
MQ_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases rabbitmq password`
rabbitmqctl add_vhost "$MQ_VHOST"
rabbitmqctl add_user "$MQ_USERNAME" "$MQ_PASSWORD"
rabbitmqctl set_permissions -p "$MQ_VHOST" "$MQ_USERNAME" '.*' '.*' '.*'
rabbitmqctl set_user_tags "$MQ_USERNAME" administrator
rabbitmq-plugins enable rabbitmq_management
systemctl restart rabbitmq-server



# Prepare server software
export SAARCTF_POSTGRES_USE_SOCKET=True
update-server noerror || echo "Please update the server later."
ln -s /usr/local/bin/update-server ~/update-server.sh



# Configure UWSGI / Control Panel
# working: uwsgi --socket 0.0.0.0:5000 --protocol=http --manage-script-name --mount /=controlserver.app:app --plugin python3
cat <<EOF > /etc/uwsgi/apps-available/controlserver.ini
[uwsgi]
env = SAARCTF_CONFIG_DIR=$SAARCTF_CONFIG_DIR
chdir = /opt/gameserver/
mount = /=controlserver.app:app
plugin = python3
manage-script-name = true
master = true
processes = 2
threads = 2
uid = saarctf
gid = saarctf

socket = /tmp/controlserver.sock
chmod-socket = 660
vacuum = true
EOF
ln -s /etc/uwsgi/apps-available/controlserver.ini /etc/uwsgi/apps-enabled/
mkdir -p /etc/systemd/system/uwsgi.service.d
cat > /etc/systemd/system/uwsgi.service.d/override.conf <<'EOF'
[Service]
MemoryAccounting=true
MemoryHigh=2900M
MemoryMax=3072M
EOF



# Configure Flower (Celery control panel)
# celery -A checker_runner flower --port=5555
cat <<'EOF' > /etc/systemd/system/flower.service
[Unit]
Description=Flower management for Celery workers
After=network.target

[Service]
Type=simple
User=saarctf
Group=saarctf
ExecStart=python3 -m celery -A checker_runner flower --address=127.0.0.1 --port=20000 --persistent=True --db=/home/saarctf/flower
WorkingDirectory=/opt/gameserver
StandardOutput=append:/var/log/flower.log
StandardError=append:/var/log/flower.log
Restart=on-failure
RestartSec=10s
EnvironmentFile=/etc/environment
TimeoutSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable flower



# Configure nginx
usermod -aG saarctf www-data  # nginx has permissions to read game files
rm -f /etc/nginx/sites-enabled/default
cat <<'EOF' > /etc/nginx/sites-available/controlserver
server {
    listen 8080;
    server_name localhost;
    location /flower/ {
        rewrite ^/flower/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:20000;
        proxy_set_header Host $host;
    }
    location / {
        include uwsgi_params;
        uwsgi_pass unix:/tmp/controlserver.sock;

        auth_basic "saarCTF Administration";
        auth_basic_user_file "$SAARCTF_CONFIG_DIR/htpasswd";
    }
}
server {
    listen 8081;
    server_name localhost;
    location / {
        proxy_pass http://127.0.0.1:20000;
        proxy_set_header Host $host;

        auth_basic "saarCTF Administration";
        auth_basic_user_file "$SAARCTF_CONFIG_DIR/htpasswd";
    }
}
EOF
cat <<'EOF' > /etc/nginx/sites-available/flower-ssl
server {
    listen 8443;
    server_name cp.ctf.saarland;
    ssl on;
    ssl_certificate /opt/config/certs/fullchain.pem;
    ssl_certificate_key /opt/config/certs/privkey.pem;
    location / {
        proxy_pass http://127.0.0.1:20000;
        proxy_set_header Host $host;

        auth_basic "saarCTF Administration";
        auth_basic_user_file "$SAARCTF_CONFIG_DIR/htpasswd";
    }
}
EOF
sed -i "s|\$SAARCTF_CONFIG_DIR|$SAARCTF_CONFIG_DIR|" /etc/nginx/sites-available/controlserver
sed -i "s|\$SAARCTF_CONFIG_DIR|$SAARCTF_CONFIG_DIR|" /etc/nginx/sites-available/flower-ssl
ln -s /etc/nginx/sites-available/controlserver /etc/nginx/sites-enabled/
cat <<'EOF' > /etc/nginx/sites-available/scoreboard
server {
    listen 80;
    server_name localhost;
    root /var/www/scoreboard/;
    access_log "/var/log/nginx/scoreboard.log" combined;

    # gzip_static on;
    gzip on;
    gzip_types "*";
    gzip_comp_level 4;
   
    etag on;

    location /api/ {
        # cache: json never
        add_header Cache-Control "max-age=0, public, must-revalidate";
    }

    location ~* \.(?:js|css|svg|woff|woff2|eot|ttf)$ {
        # cache: js/css/svg/woff/woff2/eot/ttf 1d
        add_header Cache-Control "max-age=86400, public, must-revalidate";
        access_log off;
    }

    location ~* \.(?:jpg|png|gif)$ {
        # cache: jpg/png 30min must-revalidate
        add_header Cache-Control "max-age=1800, public, must-revalidate";
        access_log off;
    }

    location ~* \.(?:html)$ {
        # cache: html 30sec
        add_header Cache-Control "max-age=30, public, must-revalidate";
    }
}
EOF
ln -s /etc/nginx/sites-available/scoreboard /etc/nginx/sites-enabled/
mkdir /var/www/scoreboard
chown saarctf:saarctf /var/www/scoreboard



# Configure service for timer script
cat <<'EOF' > /etc/systemd/system/ctftimer.service
[Unit]
Description=Central CTF timer instance
After=network.target

[Service]
Type=simple
User=saarctf
Group=saarctf
ExecStart=python3 controlserver/timer.py
WorkingDirectory=/opt/gameserver
StandardOutput=append:/var/log/ctftimer.log
StandardError=append:/var/log/ctftimer.log
Restart=on-failure
RestartSec=10s
EnvironmentFile=/etc/environment
Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONPATH=/opt/gameserver"

[Install]
WantedBy=multi-user.target
EOF
# ctftimer is not enabled by default (!)



# Configure service for scoreboard daemon
cat <<'EOF' > /etc/systemd/system/scoreboard.service
[Unit]
Description=Scoreboard daemon (generate off-site scoreboard)
After=network.target

[Service]
Type=simple
User=saarctf
Group=saarctf
ExecStart=python3 controlserver/scoring/scoreboard.py
WorkingDirectory=/opt/gameserver
StandardOutput=append:/var/log/scoreboard.log
StandardError=append:/var/log/scoreboard.log
Restart=on-failure
RestartSec=10s
EnvironmentFile=/etc/environment
Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONPATH=/opt/gameserver"

[Install]
WantedBy=multi-user.target
EOF
# scoreboard daemon is not enabled by default (!) enable only if scoreboard if not on ctftimer server



cat <<'EOF' > /etc/systemd/system/submission-server.service
[Unit]
Description=Flag submission server
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
ExecStart=/opt/gameserver/flag-submission-server/build/flag-submission-server 31337 6
WorkingDirectory=/opt/gameserver/flag-submission-server/build
StandardOutput=append:/var/log/submission-server.log
StandardError=append:/var/log/submission-server.log
Restart=on-failure
RestartSec=5s
EnvironmentFile=/etc/environment
LimitNOFILE=16384

[Install]
WantedBy=multi-user.target
EOF
systemctl enable submission-server


# Configure cronjob to recreate scoreboard
( sudo -u saarctf crontab -l; cat - <<'EOF' ) | sudo -u saarctf crontab -
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOME=/home/saarctf

# 10 */4 * * *  python3 /opt/gameserver/scripts/recreate_scoreboard.py > /home/saarctf/recreate_scoreboard.log 2>&1
EOF


# Running:
# control panel / uwsgi
# flower
# timer script (MANUAL START)
# scoreboard generator daemon (MANUAL START if timer is running on another machine)
# flag submitter
# scoreboard / nginx


echo -e '\n=== saarCTF Controller Server ===\n' > /etc/motd
echo -e "\e[2m==============================================\e[22m" >> /etc/motd
echo -e "\e[2m=\e[22m \e[1mAttention:\e[0m CTF Timer needs manual start:   \e[2m=\e[22m" >> /etc/motd
echo -e "\e[2m=\e[22m \e[22m systemctl start ctftimer                  \e[2m=\e[22m" >> /etc/motd
echo -e "\e[2m==============================================\e[22m\n" >> /etc/motd
echo "Other useful commands:" >> /etc/motd
echo " - update-server" >> /etc/motd
echo " - everything in /opt/gameserver/scripts" >> /etc/motd
echo " - systemctl restart uwsgi    (controlserver)" >> /etc/motd
echo " - systemctl restart flower" >> /etc/motd
echo " - systemctl restart ctftimer" >> /etc/motd
echo " - systemctl restart scoreboard" >> /etc/motd
echo " - systemctl restart submission-server" >> /etc/motd
echo -e "\n" >> /etc/motd

