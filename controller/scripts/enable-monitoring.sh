#!/usr/bin/env bash

set -eux

systemctl start prometheus
systemctl enable prometheus
systemctl start grafana-server
systemctl enable grafana-server

echo "Databases up and running."
