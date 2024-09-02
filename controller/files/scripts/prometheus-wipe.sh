#!/usr/bin/env bash

set -eu

systemctl stop prometheus
rm -rf /var/lib/prometheus/metrics2
systemctl start prometheus

echo "Done."
