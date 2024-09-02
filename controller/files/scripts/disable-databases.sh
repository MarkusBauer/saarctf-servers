#!/usr/bin/env bash

set -eux

systemctl stop postgresql
systemctl disable postgresql
systemctl stop redis
systemctl disable redis
systemctl stop rabbitmq-server
systemctl disable rabbitmq-server
systemctl stop influxdb
systemctl disable influxdb

echo "Databases down."
