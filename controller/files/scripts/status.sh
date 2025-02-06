#!/usr/bin/env bash

function service_state {
    STATE1=`SYSTEMD_COLORS=1 systemctl status $1 | grep Active: | cut -d ' ' -f5,6`
    STATE2=`SYSTEMD_COLORS=1 systemctl status $1 | grep Loaded: | cut -d ' ' -f7`
    printf '%-19s | %-10s | %s\n' "$2" "$STATE2" "$STATE1"
}

echo '=====  Databases   ====='
service_state "postgresql"      "Postgresql"
service_state "redis"           "Redis     "
service_state "rabbitmq-server" "RabbitMQ  "
echo ''

echo '=====     Web      ====='
service_state "nginx" "nginx"
service_state "uwsgi" "uwsgi"
echo ''

echo '===== CTF-Services ====='
service_state "ctftimer"          "CTF Timer        "
service_state "scoreboard"        "Scoreboard Daemon"
service_state "submission-server" "Submission Server"
echo ''

echo '=====  Monitoring  ====='
service_state "grafana-server" "Grafana      "
service_state "prometheus"     "Prometheus   "
service_state "prometheus-node-exporter" "Prometheus Export"
service_state "flower"         "Celery Flower"
echo ''

