#!/usr/bin/env bash

set -e

PG_SERVER=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres server`
PG_USERNAME=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres username`
PG_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres password`
PG_DATABASE=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres database`

echo ""
echo "Connecting to $PG_DATABASE@$PG_SERVER ..."
echo ""

PGPASSWORD=$PG_PASSWORD exec psql -h "$PG_SERVER" -U "$PG_USERNAME" $PG_DATABASE "$@"
