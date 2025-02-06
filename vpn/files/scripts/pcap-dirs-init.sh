#!/usr/bin/env bash

set -eu

if [ -d /mnt/pcaps ]; then
  echo "/mnt/pcaps exists, initiating directories..."
  mkdir -p /mnt/pcaps/gametraffic  /mnt/pcaps/teamtraffic /mnt/pcaps/temptraffic /mnt/pcaps/extractedtraffic
  chown nobody:nogroup /mnt/pcaps/*traffic

  test -d "/tmp/gametraffic" || ln -s /mnt/pcaps/gametraffic /tmp/
  test -d "/tmp/teamtraffic" || ln -s /mnt/pcaps/teamtraffic /tmp/
  test -d "/tmp/temptraffic" || ln -s /mnt/pcaps/temptraffic /tmp/
  test -d "/tmp/extractedtraffic" || ln -s /mnt/pcaps/extractedtraffic /tmp/
fi
echo "[[ pcap directories ready ]]"
