#!/usr/bin/env bash

set -eu

mkdir -p /root/backups
FNAME_PG=/root/backups/pgsql_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.backup
FNAME_PG2=/root/backups/pgsql_metrics_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.backup
FNAME_RD=/root/backups/redis_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.rdb


# PostgreSQL
PG_USERNAME=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases postgres username`
PG_PASSWORD=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases postgres password`
PG_DATABASE=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases postgres database`
PGPASSWORD=$PG_PASSWORD pg_dump -U "$PG_USERNAME" -F c -f "$FNAME_PG" "$PG_DATABASE"
echo "Wrote $FNAME_PG"

PGPASSWORD=$PG_PASSWORD pg_dump -U "$PG_USERNAME" -F c -f "$FNAME_PG2" "${PG_DATABASE}_metrics"
echo "Wrote $FNAME_PG2"


# Redis
REDIS_PASSWORD=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases redis password`
LAST_SAVE=`REDISCLI_AUTH=$REDIS_PASSWORD redis-cli lastsave`
REDISCLI_AUTH=$REDIS_PASSWORD redis-cli bgsave
while [ "$(REDISCLI_AUTH=$REDIS_PASSWORD redis-cli lastsave)" == "$LAST_SAVE" ]; do
	echo "... waiting for Redis save"
	sleep 0.5
done
cp /var/lib/redis/dump.rdb "$FNAME_RD"
echo "Wrote $FNAME_RD"


du -hs "$FNAME_PG" "$FNAME_PG2" "$FNAME_RD"

echo "Done."
