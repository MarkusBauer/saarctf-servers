#!/usr/bin/env bash

set -e

sudo -u saarctf bash -c 'source /etc/profile.d/env.sh ; /opt/gameserver/run.sh /opt/gameserver/scripts/recreate_scoreboard.py'
