#!/usr/bin/env bash

set -eu

# also generate configs for the next 5 teams that will register
PREGENERATE=5

git -C /opt/config pull --rebase

cd /opt/gameserver
./run.sh -u scripts/sync_teams_http.py
./run.sh -u vpn/build-openvpn-config-oneperteam.py "$PREGENERATE"
./run.sh -u vpn/build-openvpn-config-cloud.py "$PREGENERATE"

cd /opt/config
git add /opt/config/*
git commit -m "New VPN configs" && git push || echo "commit skipped"

systemctl daemon-reload
vpnctl startup

echo "Done."
