#!/usr/bin/env bash

set -eux

PG_SERVER=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases postgres server`
REDIS_SERVER=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases redis host`
REDIS_PORT=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases redis port`
REDIS_PASSWORD=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases redis password`

# Disable services
systemctl stop uwsgi
systemctl disable uwsgi
systemctl stop flower
systemctl disable flower
systemctl stop ctftimer
systemctl stop submission-server
systemctl disable submission-server
systemctl stop influxdb
systemctl disable influxdb


# switch postgresql to standby mode
systemctl stop postgresql
mv /var/lib/postgresql/*/main /var/lib/postgresql/main_old
PGPASSWORD=__REPLACE_PG_REPLICATION_PASSWORD__ pg_basebackup -h $PG_SERVER -U replicator -D /var/lib/postgresql/13/main -X stream -P
cp /root/failover/recovery.conf /var/lib/postgresql/*/main/
chown -R postgres:postgres /var/lib/postgresql/*/main/
systemctl start postgresql

systemctl stop redis
echo "replicaof $REDIS_SERVER $REDIS_PORT" >> /etc/redis/redis.conf
echo "masterauth $REDIS_PASSWORD" >> /etc/redis/redis.conf
systemctl start redis

echo "Mode changed to slave."
