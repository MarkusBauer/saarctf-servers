#!/usr/bin/env bash

set -eu

# Patch vpnboard config
if grep -q 'server_name localhost' /etc/nginx/sites-available/vpnboard; then
# Insert SSL config
sed -e '/server_name localhost;/r'<(cat - <<'EOF'
    listen 443;
    server_name vpn.ctf.saarland;
    ssl on;
    ssl_certificate /opt/config/certs/fullchain.pem;
    ssl_certificate_key /opt/config/certs/privkey.pem;

EOF
) -i /etc/nginx/sites-available/vpnboard
sed '2,3d' -i /etc/nginx/sites-available/vpnboard

# Append HTTP redirect
cat - <<'EOF' >> /etc/nginx/sites-available/vpnboard

server {
    listen 80;
    server_name vpn.ctf.saarland;
    return 301 https://$host$request_uri;
}
EOF
echo 'vpnboard config has been rewritten.'
fi



echo "Restarting nginx ..."
systemctl restart nginx
echo "Done."
