#!/usr/bin/env bash

set -eu

if [ -z ${1+x} ]; then echo "USAGE: $0 <ip>"; exit 1 ; fi

echo "Add server $1 ..."

echo "  - job_name: node_$1"           >> /etc/prometheus/prometheus.yml
echo "    static_configs:"          >> /etc/prometheus/prometheus.yml
echo "      - targets: ['$1:9100']" >> /etc/prometheus/prometheus.yml

systemctl reload prometheus

echo "Done."
