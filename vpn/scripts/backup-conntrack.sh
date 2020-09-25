#!/usr/bin/env bash

set -eu

FNAME="/root/backups/conntrack_data_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.7z"

mkdir -p /root/backups

7z a "$FNAME" "/root/conntrack_data"
