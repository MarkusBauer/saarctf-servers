#!/usr/bin/env bash

set -eux

systemctl start postgresql
systemctl enable postgresql
systemctl start redis
systemctl enable redis
systemctl start rabbitmq-server
systemctl enable rabbitmq-server

echo "Databases up and running."
