#!/usr/bin/env bash

set -eu

mkdir -p /root/backups

7z a "/root/backups/checkers_`hostname`_`date +"%Y_%m_%d__%H_%M_%S"`.7z" /home/saarctf/checkers
