#!/usr/bin/env bash

set -eu

SCOREBOARD=`python3 /opt/gameserver/saarctf_commons/config.py get scoreboard_path`
FNAME_A="/root/backups/scoreboard_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.7z"
FNAME_B="/root/backups/scoreboard_ctftime_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.json"

mkdir -p /root/backups

7z a "$FNAME_A" "$SCOREBOARD"
python3 /opt/gameserver/scripts/export_ctftime_scoreboard.py > "$FNAME_B"
