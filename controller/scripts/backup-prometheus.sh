#!/usr/bin/env bash

set -eu

mkdir -p /root/backups

FNAME_P="/root/backups/prometheus_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.7z"
FNAME_G="/root/backups/grafana_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.7z"

# request snapshot
echo "Request snapshot..."
STATUSCODE=$(curl --silent --output /dev/stderr --write-out "%{http_code}"  -XPOST "http://localhost:9090/api/v1/admin/tsdb/snapshot")
echo ""
if test $STATUSCODE -ne 200; then
    exit 1
fi

7z a "$FNAME_P" /var/lib/prometheus
7z a "$FNAME_G" /var/lib/grafana /etc/grafana/grafana.ini
