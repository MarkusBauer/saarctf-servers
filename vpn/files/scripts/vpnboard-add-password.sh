#!/usr/bin/env bash

set -e

sed -i 's|    # auth_basic |    auth_basic |' /etc/nginx/sites-available/vpnboard
sed -i 's|    # auth_basic_user_file |    auth_basic_user_file |' /etc/nginx/sites-available/vpnboard
systemctl reload nginx

echo "Done."
