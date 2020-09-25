#!/usr/bin/env bash

set -eu

mkdir -p /root/dumps
FNAME_PG=/root/dumps/pgsql_`date +"%Y_%m_%d__%H_%M_%S"`.backup
FNAME_RD=/root/dumps/redis_`date +"%Y_%m_%d__%H_%M_%S"`.rdb

PG_USERNAME=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres username`
PG_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres password`
PG_DATABASE=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres database`
PGPASSWORD=$PG_PASSWORD pg_dump -U "$PG_USERNAME" -F c -f "$FNAME_PG" "$PG_DATABASE"
echo "Wrote $FNAME_PG"


REDIS_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases redis password`
LAST_SAVE=`REDISCLI_AUTH=$REDIS_PASSWORD redis-cli lastsave`
REDISCLI_AUTH=$REDIS_PASSWORD redis-cli bgsave
while [ "$(REDISCLI_AUTH=$REDIS_PASSWORD redis-cli lastsave)" == "$LAST_SAVE" ]; do
	echo "... waiting for Redis save"
	sleep 0.5
done
cp /var/lib/redis/dump.rdb "$FNAME_RD"
echo "Wrote $FNAME_RD"

ls -lah "$FNAME_PG" "$FNAME_RD"

echo "Done."
