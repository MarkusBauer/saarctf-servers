#!/usr/bin/env bash

set -e

export INFLUX_USERNAME=admin
export INFLUX_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases postgres password`

exec influx -database saarctf "$@"
