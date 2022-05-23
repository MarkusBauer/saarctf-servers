#!/usr/bin/env bash

set -e

sed -i 's|    # auth_basic |    auth_basic |' /etc/nginx/sites-available/scoreboard
sed -i 's|    # auth_basic_user_file |    auth_basic_user_file |' /etc/nginx/sites-available/scoreboard
systemctl reload nginx

echo "Done."
