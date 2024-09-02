#!/bin/bash

set -e

# Run this script to manually add workers.
# celery-run $NAME $NUMBER

# check arguments
if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters. "
    echo "Usage: $0 <host-name> <concurreny>"
    exit 1
fi

if [ "$USER" != "saarctf" ]; then
	exec sudo -E -u saarctf "$0" "$@"
	exit 0
fi


cd /opt/gameserver
echo '>' /opt/gameserver/run.sh -m celery -A checker_runner worker -Ofair -E -Q celery,broadcast "--concurrency=$2" "--hostname=$1@%h"
exec /opt/gameserver/run.sh -m celery -A checker_runner worker -Ofair -E -Q celery,broadcast "--concurrency=$2" "--hostname=$1@%h"
