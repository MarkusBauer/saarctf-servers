#!/usr/bin/env bash

set -e

export INFLUX_USERNAME=admin
export INFLUX_PASSWORD=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get databases postgres password`

exec influx -database saarctf "$@"
