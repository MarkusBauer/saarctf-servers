#!/usr/bin/env bash

set -eux

systemctl stop prometheus
systemctl disable prometheus
systemctl stop grafana-server
systemctl disable grafana-server

echo "Databases down."
