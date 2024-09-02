#!/usr/bin/env bash

set -eux

REDIS_PASSWORD=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases redis password`

# Promote Postgresql
sudo -u postgres /usr/lib/postgresql/*/bin/pg_ctl promote -D /var/lib/postgresql/*/main

# Promote Redis
sed -i 's/^replicaof /# replicaof /' /etc/redis/redis.conf
REDISCLI_AUTH=$REDIS_PASSWORD redis-cli replicaof no one

# Start services
systemctl enable uwsgi
systemctl start uwsgi
systemctl enable flower
systemctl start flower
systemctl enable submission-server
systemctl start submission-server
systemctl enable influxdb
systemctl start influxdb

# Done
echo "Done. Please recreate scoreboard and start ctftimer."
