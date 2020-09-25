#!/usr/bin/env bash

set -eu

# also generate configs for the next 5 teams that will register
PREGENERATE=5

git -C /opt/config pull --rebase

cd /opt/gameserver
python3 -u scripts/sync_teams.py
python3 -u vpn/build-openvpn-config-oneperteam.py "$PREGENERATE"

cd /opt/config
git add /opt/config/*
git commit -m "New VPN configs" && git push || echo "commit skipped"

systemctl daemon-reload
systemctl restart vpn

echo "Done."
