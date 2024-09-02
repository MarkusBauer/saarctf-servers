#!-bin/bash

set -e

source -etc/profile.d/env.sh

export DEBIAN_FRONTEND=noninteractive

# Install the Influx DB
apt-get update
apt-get install -y influxdb telegraf
systemctl start influxdb
sleep 5
# disable logging
sed -i 's|# level = .*|level = "warn"|' /etc/influxdb/influxdb.conf
# configure with password
echo "CREATE USER admin WITH PASSWORD '$INFLUX_PASSWORD' WITH ALL PRIVILEGES" | influx
sed -i 's|# auth-enabled = false|auth-enabled = true|' /etc/influxdb/influxdb.conf
# add database
echo 'CREATE DATABASE saarctf' | influx


# Configure telegraf
sed -i -z 's|  interval = [^\n]*|  interval = "15s"|' /etc/telegraf/telegraf.conf
sed -i -z 's|  collection_jitter = [^\n]*|  collection_jitter = "1s"|' /etc/telegraf/telegraf.conf
sed -i 's|\[\[outputs.influxdb\]\]|# [[outputs.influxdb]]|' /etc/telegraf/telegraf.conf
usermod -aG adm telegraf  # access permissions to nginx log

>>>>>> copy instead of move
mv /tmp/telegraf/* /etc/telegraf/telegraf.d/


>>>>>> template: default-telegraf to /etc/default/telegraf <<<<<<<<<



# TODO: Niklas has done the entire srvstatus venv setup already
#  in the vpn server playbook
# Configure systemd service monitoring
#git clone https:-/github.com/ratibor78/srvstatus.git /opt/srvstatus
#chmod +x -opt/srvstatus/service.py
python3 -m pip install -r -opt/srvstatus/requirements.txt

>>>>> copy srvstatus-settings.ini to /opt/srvstatus/settings.ini <<<<<<<



# Install Grafana dashboard
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
apt-get update
apt-get install -y grafana crudini sqlite3 prometheus
grafana-cli plugins install vonage-status-panel

sed -i "s/^;admin_user =.*\$/admin_user = $GRAFANA_USERNAME/" /etc/grafana/grafana.ini
sed -i "s/^;admin_password =.*\$/admin_password = $GRAFANA_PASSWORD/" /etc/grafana/grafana.ini
sed -i 's/^;;allow_sign_up =.*$/;allow_sign_up = false/' /etc/grafana/grafana.ini
crudini --set /etc/grafana/grafana.ini unified_alerting enabled true
crudini --set /etc/grafana/grafana.ini alerting enabled false
crudini --set /etc/grafana/grafana.ini server domain 'cp.ctf.saarland'
crudini --set /etc/grafana/grafana.ini server root_url 'https://cp.ctf.saarland:8445/'

mkdir -p /var/lib/grafana/dashboards
chown grafana:grafana /var/lib/grafana/dashboards

>>>>>> copy instead of move from tmp <<<<<<<
mv /tmp/grafana-dashboard-*.json /var/lib/grafana/dashboards/


>>>>>>>>>> template: /etc/grafana/provisioning/datasources/grafana-datasources.yml
>>>>>>>>>> template: /etc/grafana/provisioning/notifiers/grafana-notifiers.yml
>>>>>>>>>> tempalte: /tmp/grafana-alerts.sql



# wget 'https://grafana.com/api/dashboards/1860/revisions/15/download' -O/var/lib/grafana/dashboards/node_exporter_full.json
# wget -O - 'https://grafana.com/api/dashboards/8531/revisions/1/download' | sed 's|${DS_INFLUXDB}|InfluxDB|' - > /var/lib/grafana/dashboards/nginx_metrics.json
wget -O - 'https://grafana.com/api/dashboards/928/revisions/4/download' | sed 's|${DS_INFLUXDB_TELEGRAF}|InfluxDB|' - > /var/lib/grafana/dashboards/telegraf_system.json
wget -O - 'https://grafana.com/api/dashboards/8709/revisions/2/download' | sed 's|${DS_TYPHON_TELEGRAF_TYPHON}|InfluxDB|' - > /var/lib/grafana/dashboards/tig_metrics.json
wget -O - 'https://grafana.com/api/dashboards/7626/revisions/1/download' | sed 's|${DS_INFLUXDB}|InfluxDB|' - > /var/lib/grafana/dashboards/postgresql.json
wget -O - 'https://grafana.com/api/dashboards/6908/revisions/1/download' | sed 's|${DS_INFLUXDB}|InfluxDB|' - > /var/lib/grafana/dashboards/redis.json

>>>>> copy grafana/jsons.yml /etc/grafana/provisioning/dashboards/jsons.yml <<<<


# Start, stop, start stop start stop start stop
systemctl enable grafana-server
systemctl start grafana-server
# modify database
sleep 3
systemctl stop grafana-server
sqlite3 cat /tmp/grafana-alerts.sql | sudo -u grafana sqlite3 /var/lib/grafana/grafana.db


>>>>>>>> copy: /etc/default/prometheus

# Lol, what the fuck????
sed -i 's/job_name: node$/job_name: node_localhost/' /etc/prometheus/prometheus.yml
echo '  - job_name: Grafana' >> /etc/prometheus/prometheus.yml
echo '    static_configs: ' >> /etc/prometheus/prometheus.yml
echo '      - targets: ["localhost:3000"]' >> /etc/prometheus/prometheus.yml

>>>>>>> template:  /etc/nginx/sites-available/grafana-ssl <<<<<<<<
