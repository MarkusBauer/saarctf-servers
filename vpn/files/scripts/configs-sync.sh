#!/usr/bin/env bash

set -eu

cd /opt/config
git add *
git commit -m "Config updates from VPN server" && git push || echo "commit skipped"
git pull --rebase

echo "Done."
