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


sed -i 's|-base|-vpn|g' /etc/hostname
sed -i 's|-base|-vpn|g' /etc/hosts


# Virtualbox only - configure IP on second interface
is_virtualbox && (
    echo 'allow-hotplug enp0s8' > /etc/network/interfaces.d/vboxnet
    echo 'iface enp0s8 inet static' >> /etc/network/interfaces.d/vboxnet
    echo '    address 10.32.250.1/16' >> /etc/network/interfaces.d/vboxnet
) || true

is_hetzner && (
    # ens10 = internal network adapter
    # FORWARD chain is later built by firewall / iptables management script
    # INPUT might also be overridden (check gameserver : vpn/iptables.sh)
    iptables -A INPUT -i ens10 -j ACCEPT
    iptables -A INPUT -i enp7s0 -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -i tun+ -p icmp -j ACCEPT -m comment --comment "Ping to VPN gateway"
    iptables -A INPUT -i tun+ -p udp --dport 123 -j ACCEPT -m comment --comment "NTP on VPN gateway"
    iptables -A INPUT -i tun+ -j DROP
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT -m comment --comment "SSH"
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT -m comment --comment "HTTP / VPN-Board"
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT -m comment --comment "HTTPS / VPN-Board"
    iptables -A INPUT -p udp -j ACCEPT -m comment --comment "OpenVPN servers"
    iptables -P INPUT DROP

    ip6tables -A INPUT -i ens10 -j ACCEPT
    ip6tables -A INPUT -i enp7s0 -j ACCEPT
    ip6tables -P INPUT DROP

    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
) || true


export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
    openvpn easy-rsa iptables net-tools procps libbpf-dev iftop \
    tcpdump tshark clang-7 \
    nginx telegraf
apt-get clean


# Enable IPv4 forwarding / eBPF JIT
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.core.bpf_jit_enable=1' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_max=16777216' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_expect_max=8192' >> /etc/sysctl.conf
echo 'net.netfilter.nf_conntrack_tcp_timeout_established=1800' >> /etc/sysctl.conf
echo '@reboot root /usr/bin/echo 65536 > /sys/module/nf_conntrack/parameters/hashsize' > /etc/crontab


# Link OpenVPN config
rm -r /etc/openvpn/server
ln -s "$SAARCTF_CONFIG_DIR/vpn/config-server" /etc/openvpn/server



# Configure Traffic Stats Script
cat <<'EOF' > /etc/systemd/system/trafficstats.service
[Unit]
Description=Traffic Statistics Collector
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=python3 vpn/manage-trafficstats.py
WorkingDirectory=/opt/gameserver
StandardOutput=append:/var/log/trafficstats.log
StandardError=append:/var/log/trafficstats.log
Restart=on-failure
RestartSec=20s
EnvironmentFile=/etc/environment
Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONPATH=/opt/gameserver"

[Install]
WantedBy=multi-user.target
EOF
systemctl enable trafficstats



# Configure iptables.sh firewall / routing
cat <<'EOF' > /etc/systemd/system/firewall.service
[Unit]
Description=IPTables firewall
After=network.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/opt/gameserver/vpn/iptables.sh
WorkingDirectory=/opt/gameserver
StandardOutput=append:/var/log/firewall.log
StandardError=append:/var/log/firewall.log
EnvironmentFile=/etc/environment
EOF



# Configure iptables manager
cat <<'EOF' > /etc/systemd/system/manage-iptables.service
[Unit]
Description=IPTables firewall manager
After=network.target
After=firewall.service
Requires=firewall.service
PartOf=firewall.service

[Service]
Type=simple
User=root
Group=root
ExecStart=python3 vpn/manage-iptables.py
WorkingDirectory=/opt/gameserver
StandardOutput=append:/var/log/firewall.log
StandardError=append:/var/log/firewall.log
Restart=on-failure
RestartSec=5s
EnvironmentFile=/etc/environment
Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONPATH=/opt/gameserver"

[Install]
WantedBy=multi-user.target
EOF
systemctl enable manage-iptables



# TCPDump for game traffic and team traffic
cat <<'EOF' > /etc/systemd/system/tcpdump-team.service
[Unit]
Description=Dump team traffic to pcaps
After=network.target

[Service]
Type=simple
ExecStartPre=/opt/gameserver/vpn/tcpdump/setup.sh
ExecStart=/opt/gameserver/vpn/tcpdump/run-tcpdump.sh team
WorkingDirectory=/opt/gameserver
StandardOutput=append:/var/log/tcpdump.log
StandardError=append:/var/log/tcpdump.log
Restart=on-failure
RestartSec=5s
EnvironmentFile=/etc/environment
EOF
sed 's|team|game|g' /etc/systemd/system/tcpdump-team.service > /etc/systemd/system/tcpdump-game.service
# configure AppArmor for tcpdump (thank you debian)
echo '/opt/gameserver/** rux,' >> /etc/apparmor.d/local/usr.sbin.tcpdump



# Systemd config joining all VPN servers
cat << 'EOF' > /etc/systemd/system/vpn@.service
[Unit]
Description=OpenVPN service for %I
After=network-online.target
Wants=network-online.target
Documentation=man:openvpn(8)
Documentation=https://community.openvpn.net/openvpn/wiki/Openvpn24ManPage
Documentation=https://community.openvpn.net/openvpn/wiki/HOWTO

[Service]
Type=notify
#PrivateTmp=true
WorkingDirectory=/etc/openvpn/server
#ExecStart=/usr/sbin/openvpn --status %t/openvpn-server/status-%i.log --status-version 2 --suppress-timestamps --config %i.conf
ExecStart=/usr/sbin/openvpn --config %i.conf
ExecStopPost=+/opt/gameserver/vpn/on-disconnect.sh %i
#CapabilityBoundingSet=CAP_IPC_LOCK CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SETGID CAP_SETUID CAP_SYS_CHROOT CAP_DAC_OVERRIDE CAP_AUDIT_WRITE
#LimitNPROC=10
DeviceAllow=/dev/null rw
DeviceAllow=/dev/net/tun rw
ProtectSystem=true
ProtectHome=true
KillMode=process
RestartSec=5s
Restart=on-failure

StandardOutput=append:/var/log/vpn/output-%i.log
StandardError=append:/var/log/vpn/output-%i.log
EnvironmentFile=/etc/environment
Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONPATH=/opt/gameserver"

[Install]
WantedBy=multi-user.target
EOF


cat << 'EOF' > /etc/systemd/system/vpn2@.service
[Unit]
Description=OpenVPN service for %I
After=network-online.target
Wants=network-online.target
Documentation=man:openvpn(8)
Documentation=https://community.openvpn.net/openvpn/wiki/Openvpn24ManPage
Documentation=https://community.openvpn.net/openvpn/wiki/HOWTO

[Service]
Type=notify
#PrivateTmp=true
WorkingDirectory=/etc/openvpn/server
#ExecStart=/usr/sbin/openvpn --status %t/openvpn-server/status-%i.log --status-version 2 --suppress-timestamps --config %i.conf
ExecStart=/usr/sbin/openvpn --config %i.conf
#ExecStopPost=+/opt/gameserver/vpn/on-disconnect.sh %i
#CapabilityBoundingSet=CAP_IPC_LOCK CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SETGID CAP_SETUID CAP_SYS_CHROOT CAP_DAC_OVERRIDE CAP_AUDIT_WRITE
#LimitNPROC=10
DeviceAllow=/dev/null rw
DeviceAllow=/dev/net/tun rw
ProtectSystem=true
ProtectHome=true
KillMode=process
RestartSec=5s
Restart=on-failure

StandardOutput=append:/var/log/vpn/output-%i.log
StandardError=append:/var/log/vpn/output-%i.log
EnvironmentFile=/etc/environment
Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONPATH=/opt/gameserver"

[Install]
WantedBy=multi-user.target
EOF


mkdir -p /var/log/vpn
ln -s "$SAARCTF_CONFIG_DIR/vpn/vpn.service" /etc/systemd/system/vpn.service
systemctl enable vpn || true



# Configure VPN board daemon
cat <<'EOF' > /etc/systemd/system/vpnboard.service
[Unit]
Description=VPN Status website
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
# add "--check-vulnbox" to ping vulnboxes
ExecStart=python3 vpnboard/vpn_board.py --daemon
WorkingDirectory=/opt/gameserver
StandardOutput=append:/var/log/vpnboard-results.log
StandardError=append:/var/log/vpnboard.log
Restart=on-failure
RestartSec=10s
EnvironmentFile=/etc/environment
Environment="PYTHONUNBUFFERED=1"
Environment="PYTHONPATH=/opt/gameserver"

[Install]
WantedBy=multi-user.target
EOF
systemctl enable vpnboard
# Configure nginx for the VPN board
rm -f /etc/nginx/sites-enabled/default
cat <<'EOF' > /etc/nginx/sites-available/vpnboard
server {
    listen 80;
    server_name localhost;
    root /var/www/scoreboard/;
    access_log "/var/log/nginx/vpnboard.log";

    etag on;
}
EOF
ln -s /etc/nginx/sites-available/vpnboard /etc/nginx/sites-enabled/
mkdir -p /var/www/scoreboard
chown www-data:www-data /var/www/scoreboard
ln -s /var/www/scoreboard/vpn.html /var/www/scoreboard/index.html
# configure celery
cat <<'EOF' > /etc/systemd/system/vpnboard-celery.service
[Unit]
Description=Celery Workers for saarCTF (VPNBoard)
After=network.target

[Service]
Type=forking
User=www-data
Group=www-data
EnvironmentFile=/etc/environment
EnvironmentFile=/etc/vpncelery.conf
WorkingDirectory=/opt/gameserver
ExecStart=/bin/sh -c 'python3 -m celery multi start ${CELERYD_NODES} -A vpnboard -Ofair -E -Q vpnboard \
	--pidfile=/var/run/celery/vpn-%n.pid --logfile="/var/log/celery/vpn-%n%I.log" --loglevel=${CELERYD_LOG_LEVEL} --concurrency=${CELERYD_CONCURRENCY} ${CELERYD_OPTS}'
ExecStop=/bin/sh -c 'python3 -m celery multi stopwait ${CELERYD_NODES} --pidfile=/var/run/celery/vpn-%n.pid'
ExecReload=/bin/sh -c 'python3 -m celery multi restart ${CELERYD_NODES} -A vpnboard -Ofair -E -Q vpnboard \
	--pidfile=/var/run/celery/vpn-%n.pid --logfile="/var/log/celery/vpn-%n%I.log" --loglevel=${CELERYD_LOG_LEVEL} --concurrency=${CELERYD_CONCURRENCY} ${CELERYD_OPTS}'
RuntimeDirectory=celery

[Install]
WantedBy=multi-user.target
EOF
echo 'CELERYD_NODES=vpnboard' > /etc/vpncelery.conf
echo 'CELERYD_CONCURRENCY="16"' >> /etc/vpncelery.conf
echo 'CELERYD_LOG_LEVEL=INFO' >> /etc/vpncelery.conf
echo 'CELERYD_OPTS="--time-limit=60"' >> /etc/vpncelery.conf
mkdir /var/log/celery
chown www-data:www-data /var/log/celery
systemctl enable vpnboard-celery


# Crontab entry to synchronize teams - enable once ready
( crontab -l; cat - <<'EOF' ) | crontab -
PATH=/opt/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SHELL=/bin/bash
HOME=/root

# 5 */4 * * *  /root/configs-create.sh > /var/log/configs-create.log 2>&1
EOF




# run iptables.sh on startup
# manage-iptables (later)
# manage-trafficstats
# run all the openvpn server
# tcpdump


# notification on login about that scripts
echo -e '\n=== saarCTF VPN Gateway ===\n' > /etc/motd
echo -e "\e[2m===============================================\e[22m" >> /etc/motd
echo -e "\e[2m=\e[22m \e[1mAttention:\e[0m tcpdump needs manual start:      \e[2m=\e[22m" >> /etc/motd
echo -e "\e[2m=\e[22m systemctl start tcpdump-team                \e[2m=\e[22m" >> /etc/motd
echo -e "\e[2m=\e[22m systemctl start tcpdump-game                \e[2m=\e[22m" >> /etc/motd
echo -e "\e[2m===============================================\e[22m" >> /etc/motd
echo -e "\nOther systemd services:" >> /etc/motd
echo -e " - vpn / vpn@teamX  (openvpn servers)" >> /etc/motd
echo -e " - vpncloud / vpn@teamX-vulnbox / vpn2@teamX-cloud  (openvpn servers, cloud mode)" >> /etc/motd
echo -e " - firewall         (iptables ruleset)" >> /etc/motd
echo -e " - manage-iptables  (vpn on/off script)" >> /etc/motd
echo -e " - trafficstats     (statistics collector)" >> /etc/motd
echo -e " - vpnboard         (vpn statistics website)" >> /etc/motd
echo -e " - vpnboard-celery  (workers for vpnboard)" >> /etc/motd
echo -e " - conntrack-accounting / conntrack-psql-insert  (conntrack monitoring)" >> /etc/motd
echo -e "\n" >> /etc/motd
