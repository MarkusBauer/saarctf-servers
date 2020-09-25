#!/usr/bin/env bash

set -e

source /etc/profile.d/env.sh

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y telegraf

# Configure telegraf
export INFLUX_USERNAME=admin
export INFLUX_SERVER=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres server`
export INFLUX_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres password`
sed -i -z 's|  interval = [^\n]*|  interval = "15s"|' /etc/telegraf/telegraf.conf
sed -i -z 's|  collection_jitter = [^\n]*|  collection_jitter = "1s"|' /etc/telegraf/telegraf.conf
sed -i 's|\[\[outputs.influxdb\]\]|# [[outputs.influxdb]]|' /etc/telegraf/telegraf.conf
mv /tmp/telegraf/* /etc/telegraf/telegraf.d/
# Put all relevant infos into environment variables
echo "INFLUX_URL=http://$INFLUX_SERVER:8086" >> /etc/default/telegraf
echo "INFLUX_PASSWORD=$INFLUX_PASSWORD" >> /etc/default/telegraf
# Give telegraf "ping" permissions
mkdir -p /etc/systemd/system/telegraf.service.d
cat - > /etc/systemd/system/telegraf.service.d/override.conf <<'EOF'
[Service]
CapabilityBoundingSet=CAP_NET_RAW
AmbientCapabilities=CAP_NET_RAW
EOF

# Configure systemd service monitoring
#git clone https://github.com/ratibor78/srvstatus.git /opt/srvstatus
#chmod +x /opt/srvstatus/service.py
python3 -m pip install -r /opt/srvstatus/requirements.txt
cat - > /opt/srvstatus/settings.ini <<'EOF'
[SERVICES]
name = conntrack-accounting.service conntrack-psql-insert.service firewall.service manage-iptables.service nginx.service prometheus-node-exporter.service ssh.service telegraf.service trafficstats.service vpnboard-celery.service vpnboard.service vpn.service vpnboard-celery.service tcpdump-team.service tcpdump-game.service
EOF



# Install configure conntrack accounting tool
PG_SERVER=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres server`
PG_USERNAME=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres username`
PG_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres password`
PG_DATABASE=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres database`

wget "https://dl.google.com/go/go1.15.linux-amd64.tar.gz" -O/tmp/go.tar.gz
tar -xf /tmp/go.tar.gz -C /opt
echo 'export GOROOT=/opt/go' >> /etc/profile.d/env.sh
echo 'export PATH=$GOROOT/bin:$PATH' >> /etc/profile.d/env.sh
source /etc/profile.d/env.sh
git clone "$CONNTRACK_ACCOUNTING_GIT_REPO" /opt/conntrack_accounting
cd /opt/conntrack_accounting/conntrack_accounting_tool
go build
cd /opt/conntrack_accounting/conntrack_psql_insert
go build

mkdir -p /root/conntrack_data/new
mkdir -p /root/conntrack_data/processed

cat <<'EOF' > /root/ports.conf
# insert all service ports here (one per line)!
# file is watched and will be reloaded upon change
tcp:22
tcp:80
tcp:31337
EOF

cat <<'EOF' > /etc/systemd/system/conntrack-accounting.service
[Unit]
Description=Conntrack Traffic Accounting Tool
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/opt/conntrack_accounting/conntrack_accounting_tool/conntrack_accounting -src=10.32.0.0/11 -src-group-mask=255.239.255.0 -dst=10.32.0.0/11 -dst-group-mask=255.239.255.0 -exclude-ip=10.32.250.1 -pipe=/tmp/conntrack_acct -output=/root/conntrack_data/new -ports=/root/ports.conf -track-open -interval=15
WorkingDirectory=/opt/conntrack_accounting
StandardOutput=append:/var/log/conntrack_accounting.log
StandardError=append:/var/log/conntrack_accounting.log
Restart=on-failure
RestartSec=5s
EnvironmentFile=/etc/environment

[Install]
WantedBy=multi-user.target
EOF
systemctl enable conntrack-accounting
cat <<EOF > /etc/systemd/system/conntrack-psql-insert.service
[Unit]
Description=Conntrack Traffic Accounting to psql Tool
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/opt/conntrack_accounting/conntrack_psql_insert/psql_insert -host=$PG_SERVER -db=$PG_DATABASE -user=$PG_USERNAME -pass=$PG_PASSWORD -watch=/root/conntrack_data/new -move=/root/conntrack_data/processed
WorkingDirectory=/opt/conntrack_accounting
StandardOutput=append:/var/log/conntrack_accounting_psql.log
StandardError=append:/var/log/conntrack_accounting_psql.log
Restart=on-failure
RestartSec=5s
EnvironmentFile=/etc/environment

[Install]
WantedBy=multi-user.target
EOF
systemctl enable conntrack-psql-insert
