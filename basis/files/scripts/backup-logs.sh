#!/usr/bin/env bash

set -eu

mkdir -p /root/backups

7z a "/root/backups/logs_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.7z" /var/log "-x!log/installer"
