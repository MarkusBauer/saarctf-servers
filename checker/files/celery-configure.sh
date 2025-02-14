#!/bin/bash

set -e

# Run this script after creating a new server. Usage:
# celery-configure $HOST_NUMBER

# check arguments
if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters. "
    echo "Usage: $0 <host-number>"
    exit 1
fi


is_virtualbox() {
  (dmidecode -t system|grep 'Manufacturer\|Product' | grep -q 'VirtualBox')
  return $?
}


HOST_NUMBER="$1"

sed -i -E "s|CELERYD_NODES=.*|CELERYD_NODES=worker${HOST_NUMBER}|" /etc/celery.conf
sed -i -E "s|CELERYD_NODES=.*|CELERYD_NODES=worker${HOST_NUMBER}-selenium|" /etc/celery-selenium.conf
sed -i -E "s|CELERYD_NODES=.*|CELERYD_NODES=worker${HOST_NUMBER}-rawsocket|" /etc/celery-rawsocket.conf
sed -i -E "s|CELERYD_NODES=.*|CELERYD_NODES=worker${HOST_NUMBER}-loadtest|" /etc/celery-loadtest.conf
sed -i -E "s|CELERYD_NODES=.*|CELERYD_NODES=worker${HOST_NUMBER}-tests|" /etc/celery-tests.conf
sed -i -E "s|CELERYD_CONCURRENCY=.*|CELERYD_CONCURRENCY=$((4*$(nproc)))|" /etc/celery.conf
sed -i -E "s|CELERYD_CONCURRENCY=.*|CELERYD_CONCURRENCY=$(nproc)|" /etc/celery-selenium.conf
sed -i -E "s|CELERYD_CONCURRENCY=.*|CELERYD_CONCURRENCY=$(nproc)|" /etc/celery-rawsocket.conf
sed -i -E "s|CELERYD_CONCURRENCY=.*|CELERYD_CONCURRENCY=48|" /etc/celery-loadtest.conf
sed -i -E "s|CELERYD_CONCURRENCY=.*|CELERYD_CONCURRENCY=4|" /etc/celery-tests.conf
is_virtualbox && (
  sed -i -E "s|-checker-\w+|-checker-${HOST_NUMBER}|g" /etc/hostname
  sed -i -E "s|-checker-\w+|-checker-${HOST_NUMBER}|g" /etc/hosts
  hostname "saarctf-checker-${HOST_NUMBER}"
  echo "Hostname = `hostname`"
) || true
echo "Celery config: `head -1 /etc/celery.conf`"


echo ""
echo "=== Installing service dependencies ==="

cd /opt/gameserver
/opt/gameserver/run.sh scripts/service_setup_scripts.py

echo ""
echo ""


echo "Starting celery ..."
systemctl enable celery
systemctl start celery
systemctl enable celery-loadtest
systemctl start celery-loadtest
systemctl enable celery-tests
systemctl start celery-tests
sleep 1
systemctl status celery
echo "Done."
echo "Service celery: $(grep 'CELERYD_CONCURRENCY' /etc/celery.conf)"
echo "Service celery-loadtest: $(grep 'CELERYD_CONCURRENCY' /etc/celery-loadtest.conf)
echo "Service celery-tests: $(grep 'CELERYD_CONCURRENCY' /etc/celery-tests.conf)
echo "Service celery-selenium: $(grep 'CELERYD_CONCURRENCY' /etc/celery-selenium.conf) (disabled by default)"
echo "Service celery-rawsocket: $(grep 'CELERYD_CONCURRENCY' /etc/celery-rawsocket.conf) (disabled by default)"
