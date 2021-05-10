#!/usr/bin/env bash

set -eu

cd /opt/gameserver
python3 -u scripts/sync_teams_http.py
