#!/usr/bin/env bash

set -eu

cd /opt/gameserver
./run.sh -u scripts/sync_teams_http.py
