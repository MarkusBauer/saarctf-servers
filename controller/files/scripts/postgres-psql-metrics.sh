#!/usr/bin/env bash

set -e

PG_SERVER=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases postgres server`
PG_USERNAME=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases postgres username`
PG_PASSWORD=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases postgres password`
PG_DATABASE=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases postgres database`_metrics

echo ""
echo "Connecting to $PG_DATABASE@$PG_SERVER ..."
echo ""

PGPASSWORD=$PG_PASSWORD exec psql -h "$PG_SERVER" -U "$PG_USERNAME" $PG_DATABASE "$@"
