#!/usr/bin/env bash

MQ_VHOST=`python3 /opt/gameserver/saarctf_commons/config.py get databases rabbitmq vhost`
MQ_USERNAME=`python3 /opt/gameserver/saarctf_commons/config.py get databases rabbitmq username`
MQ_PASSWORD=`python3 /opt/gameserver/saarctf_commons/config.py get databases rabbitmq password`
rabbitmqctl add_vhost "$MQ_VHOST"
rabbitmqctl add_user "$MQ_USERNAME" "$MQ_PASSWORD"
rabbitmqctl set_permissions -p "$MQ_VHOST" "$MQ_USERNAME" '.*' '.*' '.*'
rabbitmqctl set_user_tags "$MQ_USERNAME" administrator
rabbitmq-plugins enable rabbitmq_management
systemctl restart rabbitmq-server

echo "Done."
