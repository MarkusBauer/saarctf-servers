#!/usr/bin/env bash

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


sed -i 's|-base|-checker-x|g' /etc/hostname
sed -i 's|-base|-checker-x|g' /etc/hosts

# Virtualbox only - routes
is_virtualbox && (
    echo '    up ip route add 10.32.0.0/17 via 10.32.250.1' >> /etc/network/interfaces.d/vboxnet
    echo '    up ip route add 10.32.128.0/18 via 10.32.250.1' >> /etc/network/interfaces.d/vboxnet
    echo '    up ip route add 10.32.192.0/19 via 10.32.250.1' >> /etc/network/interfaces.d/vboxnet
    echo '    up ip route add 10.33.0.0/16 via 10.32.250.1' >> /etc/network/interfaces.d/vboxnet
    echo '    up ip route add 10.48.16.0/15 via 10.32.250.1' >> /etc/network/interfaces.d/vboxnet
) || true

is_hetzner && (
    iptables -A INPUT -i ens10 -j ACCEPT
    iptables -A INPUT -i enp7s0 -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -P INPUT DROP

    ip6tables -A INPUT -i ens10 -j ACCEPT
    ip6tables -A INPUT -i enp7s0 -j ACCEPT
    ip6tables -A INPUT -i lo -j ACCEPT
    ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
    ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A INPUT -p icmpv6 -j ACCEPT
    ip6tables -P INPUT DROP

    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
) || true


export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y build-essential libssl-dev libffi-dev
pip3 install -r /opt/gameserver/requirements-script.txt

# Make user
useradd saarctf -m -U -s "/bin/bash"
echo 'source /etc/profile.d/env.sh' >> /home/saarctf/.profile
echo 'source /etc/profile.d/env.sh' >> /home/saarctf/.bashrc
mkdir -p /home/saarctf/checker_cache
chown -R saarctf:saarctf /home/saarctf/checker_cache



cat <<'EOF' > /etc/systemd/system/celery.service
[Unit]
Description=Celery Workers for saarCTF
After=network.target

[Service]
Type=forking
User=saarctf
Group=saarctf
EnvironmentFile=/etc/environment
EnvironmentFile=/etc/celery.conf
WorkingDirectory=/opt/gameserver
ExecStart=/bin/sh -c 'python3 -m celery -A checker_runner multi start ${CELERYD_NODES} -Ofair -E -Q celery,broadcast \
	--pidfile=/var/run/celery/%n.pid --logfile="/var/log/celery/%n%I.log" --loglevel=${CELERYD_LOG_LEVEL} --concurrency=${CELERYD_CONCURRENCY} ${CELERYD_OPTS}'
ExecStop=/bin/sh -c 'python3 -m celery multi stopwait ${CELERYD_NODES} --pidfile=/var/run/celery/%n.pid'
ExecReload=/bin/sh -c 'python3 -m celery -A checker_runner multi restart ${CELERYD_NODES} -Ofair -E -Q celery,broadcast \
	--pidfile=/var/run/celery/%n.pid --logfile="/var/log/celery/%n%I.log" --loglevel=${CELERYD_LOG_LEVEL} --concurrency=${CELERYD_CONCURRENCY} ${CELERYD_OPTS}'
RuntimeDirectory=celery
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
# custom configs for special services
cp /etc/systemd/system/celery.service /etc/systemd/system/celery-selenium.service
sed -i 's|celery.conf|celery-selenium.conf|' /etc/systemd/system/celery-selenium.service
sed -i 's|celery,broadcast|selenium|g' /etc/systemd/system/celery-selenium.service
cp /etc/systemd/system/celery.service /etc/systemd/system/celery-rawsocket.service
sed -i 's|celery.conf|celery-rawsocket.conf|' /etc/systemd/system/celery-rawsocket.service
sed -i 's|celery,broadcast|rawsocket|g' /etc/systemd/system/celery-rawsocket.service
sed -i '18i AmbientCapabilities=CAP_NET_RAW' /etc/systemd/system/celery-rawsocket.service


echo 'CELERYD_NODES=worker1' > /etc/celery.conf
echo 'CELERYD_CONCURRENCY="16"' >> /etc/celery.conf
echo 'CELERYD_LOG_LEVEL=INFO' >> /etc/celery.conf
echo 'CELERYD_OPTS="--time-limit=60"' >> /etc/celery.conf
echo 'SAARCTF_CACHE_PATH=/home/saarctf/checker_cache' >> /etc/celery.conf
# Selenium
echo 'CELERYD_NODES=worker1-selenium' > /etc/celery-selenium.conf
echo 'CELERYD_CONCURRENCY="4"' >> /etc/celery-selenium.conf
echo 'CELERYD_LOG_LEVEL=INFO' >> /etc/celery-selenium.conf
echo 'CELERYD_OPTS="--time-limit=60"' >> /etc/celery-selenium.conf
echo 'SAARCTF_CACHE_PATH=/home/saarctf/checker_cache' >> /etc/celery-selenium.conf
echo 'SAARCTF_NO_RLIMIT=1' >> /etc/celery-selenium.conf
# Raw Sockets
echo 'CELERYD_NODES=worker1-rawsocket' > /etc/celery-rawsocket.conf
echo 'CELERYD_CONCURRENCY="8"' >> /etc/celery-rawsocket.conf
echo 'CELERYD_LOG_LEVEL=INFO' >> /etc/celery-rawsocket.conf
echo 'CELERYD_OPTS="--time-limit=60"' >> /etc/celery-rawsocket.conf
echo 'SAARCTF_CACHE_PATH=/home/saarctf/checker_cache' >> /etc/celery-rawsocket.conf



mkdir /var/log/celery
chown saarctf /var/log/celery


# Run configure on startup to initialize things!
# notification on login about that scripts
echo -e '\n=== saarCTF Checker Server ===\n' > /etc/motd
echo -e "\e[2m=====================================================================\e[22m" >> /etc/motd
echo -e "\e[2m=\e[22m \e[1mAttention:\e[0m Servers need setup first:                              \e[2m=\e[22m" >> /etc/motd
echo -e "\e[2m=\e[22m Call \"celery-configure <server-number>\" to bring checkers online. \e[2m=\e[22m" >> /etc/motd
echo -e "\e[2m=====================================================================\e[22m\n" >> /etc/motd
echo "Other useful commands:" >> /etc/motd
echo " - systemctl restart celery" >> /etc/motd
echo " - celery-run <hostname> <concurrency>" >> /etc/motd
echo "Check out /etc/celery.conf to change concurrency." >> /etc/motd
echo -e "\n" >> /etc/motd
