#!/usr/bin/env bash

set -eu

SCOREBOARD=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get scoreboard_path`
PATCHES=`/opt/gameserver/run.sh /opt/gameserver/saarctf_commons/config.py get patches_path`
FNAME_A="/root/backups/scoreboard_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.7z"
FNAME_B="/root/backups/scoreboard_ctftime_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.json"
FNAME_C="/root/backups/patches_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.7z"

mkdir -p /root/backups

7z a "$FNAME_A" "$SCOREBOARD"
/opt/gameserver/run.sh /opt/gameserver/scripts/export_ctftime_scoreboard.py > "$FNAME_B"
7z a "$FNAME_C" "$PATCHES"
