#!/usr/bin/env bash

set -eu

if [ ! -f $SAARCTF_CONFIG_DIR/keystore.json ]; then
  gspython /opt/gameserver/wireguard-sync/wireguard_sync generate
  /root/configs-sync.sh
  echo "Done."
else
  echo "keystore.json already exists"
fi

