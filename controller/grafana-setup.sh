#!/bin/bash

set -e

source /etc/profile.d/env.sh

export DEBIAN_FRONTEND=noninteractive
export INFLUX_USERNAME=admin
export INFLUX_SERVER=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres server`
export INFLUX_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres password`


# Install the Influx DB
apt-get update
apt-get install -y influxdb telegraf
systemctl start influxdb
sleep 5
# disable logging
sed -i 's|# level = .*|level = "warn"|' /etc/influxdb/influxdb.conf
# configure with password
echo "CREATE USER $INFLUX_USERNAME WITH PASSWORD '$INFLUX_PASSWORD' WITH ALL PRIVILEGES" | influx
sed -i 's|# auth-enabled = false|auth-enabled = true|' /etc/influxdb/influxdb.conf
# add database
echo 'CREATE DATABASE saarctf' | influx
# TODO add backup


# Configure telegraf
sed -i -z 's|  interval = [^\n]*|  interval = "15s"|' /etc/telegraf/telegraf.conf
sed -i -z 's|  collection_jitter = [^\n]*|  collection_jitter = "1s"|' /etc/telegraf/telegraf.conf
sed -i 's|\[\[outputs.influxdb\]\]|# [[outputs.influxdb]]|' /etc/telegraf/telegraf.conf
usermod -aG adm telegraf  # access permissions to nginx log
mv /tmp/telegraf/* /etc/telegraf/telegraf.d/
# Put all relevant infos into environment variables
PG_SERVER=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres server`
PG_USERNAME=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres username`
PG_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres password`
PG_DATABASE=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres database`
REDIS_HOST=`python3 /opt/gameserver/saarctf_commons/config.py get databases redis host`
REDIS_PORT=`python3 /opt/gameserver/saarctf_commons/config.py get databases redis port`
REDIS_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases redis password`
MQ_HOST=`python3 /opt/gameserver/saarctf_commons/config.py get databases rabbitmq host`
MQ_VHOST=`python3 /opt/gameserver/saarctf_commons/config.py get databases rabbitmq vhost`
MQ_USERNAME=`python3 /opt/gameserver/saarctf_commons/config.py get databases rabbitmq username`
MQ_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases rabbitmq password`
echo "INFLUX_URL=http://$INFLUX_SERVER:8086" >> /etc/default/telegraf
echo "INFLUX_PASSWORD=$INFLUX_PASSWORD" >> /etc/default/telegraf
echo "PG_SERVER=$PG_SERVER" >> /etc/default/telegraf
echo "PG_USERNAME=$PG_USERNAME" >> /etc/default/telegraf
echo "PG_PASSWORD=$PG_PASSWORD" >> /etc/default/telegraf
echo "PG_DATABASE=$PG_DATABASE" >> /etc/default/telegraf
echo "REDIS_HOST=$REDIS_HOST" >> /etc/default/telegraf
echo "REDIS_PORT=$REDIS_PORT" >> /etc/default/telegraf
echo "REDIS_PASSWORD=$REDIS_PASSWORD" >> /etc/default/telegraf
echo "MQ_HOST=$MQ_HOST" >> /etc/default/telegraf
echo "MQ_VHOST=$MQ_VHOST" >> /etc/default/telegraf
echo "MQ_USERNAME=$MQ_USERNAME" >> /etc/default/telegraf
echo "MQ_PASSWORD=$MQ_PASSWORD" >> /etc/default/telegraf

# Configure systemd service monitoring
#git clone https://github.com/ratibor78/srvstatus.git /opt/srvstatus
#chmod +x /opt/srvstatus/service.py
python3 -m pip install -r /opt/srvstatus/requirements.txt
cat - > /opt/srvstatus/settings.ini <<'EOF'
[SERVICES]
name = ctftimer.service flower.service grafana-server.service influxdb.service nginx.service postgresql@13-main.service prometheus-node-exporter.service prometheus.service rabbitmq-server.service redis-server.service ssh.service submission-server.service telegraf.service uwsgi.service
EOF



# Install Grafana dashboard
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
apt-get update
apt-get install -y grafana crudini sqlite3
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
mv /tmp/grafana-datasources.yml /etc/grafana/provisioning/datasources/
mv /tmp/grafana-notifiers.yml /etc/grafana/provisioning/notifiers/
sed -i "s|INFLUXDB_PASSWORD|$INFLUX_PASSWORD|" /etc/grafana/provisioning/datasources/grafana-datasources.yml
sed -i "s|PG_USERNAME|$PG_USERNAME|" /etc/grafana/provisioning/datasources/grafana-datasources.yml
sed -i "s|PG_PASSWORD|$PG_PASSWORD|" /etc/grafana/provisioning/datasources/grafana-datasources.yml
sed -i "s|HTACCESS_USERNAME|$HTACCESS_USERNAME|" /etc/grafana/provisioning/notifiers/grafana-notifiers.yml
sed -i "s|HTACCESS_PASSWORD|$HTACCESS_PASSWORD|" /etc/grafana/provisioning/notifiers/grafana-notifiers.yml
sed -i "s|HTACCESS_USERNAME|$HTACCESS_USERNAME|" /tmp/grafana-alerts.sql
sed -i "s|HTACCESS_PASSWORD|$HTACCESS_PASSWORD|" /tmp/grafana-alerts.sql
mv /tmp/grafana-dashboard-*.json /var/lib/grafana/dashboards/
sed -i 's|${DS_CTF_DB}|CTF DB|' /var/lib/grafana/dashboards/*_psql.json
sed -i 's|${DS_INFLUXDB}|InfluxDB|' /var/lib/grafana/dashboards/*_psql.json
# wget 'https://grafana.com/api/dashboards/1860/revisions/15/download' -O/var/lib/grafana/dashboards/node_exporter_full.json
# wget -O - 'https://grafana.com/api/dashboards/8531/revisions/1/download' | sed 's|${DS_INFLUXDB}|InfluxDB|' - > /var/lib/grafana/dashboards/nginx_metrics.json
wget -O - 'https://grafana.com/api/dashboards/928/revisions/4/download' | sed 's|${DS_INFLUXDB_TELEGRAF}|InfluxDB|' - > /var/lib/grafana/dashboards/telegraf_system.json
wget -O - 'https://grafana.com/api/dashboards/8709/revisions/2/download' | sed 's|${DS_TYPHON_TELEGRAF_TYPHON}|InfluxDB|' - > /var/lib/grafana/dashboards/tig_metrics.json
wget -O - 'https://grafana.com/api/dashboards/7626/revisions/1/download' | sed 's|${DS_INFLUXDB}|InfluxDB|' - > /var/lib/grafana/dashboards/postgresql.json
wget -O - 'https://grafana.com/api/dashboards/6908/revisions/1/download' | sed 's|${DS_INFLUXDB}|InfluxDB|' - > /var/lib/grafana/dashboards/redis.json
cat <<EOF > /etc/grafana/provisioning/dashboards/jsons.yml
apiVersion: 1
providers:
- name: 'default'       # name of this dashboard configuration (not dashboard itself)
  org_id: 1             # id of the org to hold the dashboard
  folder: ''            # name of the folder to put the dashboard (http://docs.grafana.org/v5.0/reference/dashboard_folders/)
  type: 'file'          # type of dashboard description (json files)
  editable: true
  allowUiUpdates: true
  options:
    folder: '/var/lib/grafana/dashboards'
EOF

systemctl enable grafana-server
systemctl start grafana-server

# modify database
sleep 3
systemctl stop grafana-server
sqlite3 cat /tmp/grafana-alerts.sql | sudo -u grafana sqlite3 /var/lib/grafana/grafana.db


# Install Prometheus monitoring
apt-get install -y prometheus
echo 'ARGS="--web.listen-address=127.0.0.1:9090 --web.enable-admin-api"' >> /etc/default/prometheus
sed -i 's/job_name: node$/job_name: node_localhost/' /etc/prometheus/prometheus.yml
echo '  - job_name: Grafana' >> /etc/prometheus/prometheus.yml
echo '    static_configs: ' >> /etc/prometheus/prometheus.yml
echo '      - targets: ["localhost:3000"]' >> /etc/prometheus/prometheus.yml


# Install nginx SSL frontend
cat <<'EOF' > /etc/nginx/sites-available/grafana-ssl
server {
    listen 8445 ssl;
    server_name cp.ctf.saarland;
    ssl_certificate /opt/config/certs/fullchain.pem;
    ssl_certificate_key /opt/config/certs/privkey.pem;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
    }

    client_max_body_size 128m;
    client_header_buffer_size 1024k;
    large_client_header_buffers 16 1024k;
    client_body_buffer_size 2m;
}
EOF
