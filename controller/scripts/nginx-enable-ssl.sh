#!/usr/bin/env bash

set -eu

# Patch scoreboard config
if grep -q 'server_name localhost' /etc/nginx/sites-available/scoreboard; then
	# Insert SSL config
sed -e '/server_name localhost;/r'<(cat - <<'EOF'
    listen 443 ssl;
    server_name scoreboard.ctf.saarland;
    ssl_certificate /opt/config/certs/fullchain.pem;
    ssl_certificate_key /opt/config/certs/privkey.pem;

EOF
) -i /etc/nginx/sites-available/scoreboard
sed '2,3d' -i /etc/nginx/sites-available/scoreboard

# Append HTTP redirect
cat - <<'EOF' >> /etc/nginx/sites-available/scoreboard

server {
    listen 80;
    server_name scoreboard.ctf.saarland;

    location /saarctf_nginx_status {
        stub_status;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
EOF
echo 'scoreboard config has been rewritten.'
fi


# Patch controlserver config
if grep -q 'listen 8080' /etc/nginx/sites-available/controlserver; then
	# Insert SSL config
sed -e '/server_name localhost;/r'<(cat - <<'EOF'
    listen 443 ssl;
    server_name cp.ctf.saarland;
    ssl_certificate /opt/config/certs/fullchain.pem;
    ssl_certificate_key /opt/config/certs/privkey.pem;

EOF
) -i /etc/nginx/sites-available/controlserver
sed '2,3d' -i /etc/nginx/sites-available/controlserver

echo 'controlserver config has been rewritten.'
fi


ln -s /etc/nginx/sites-available/flower-ssl /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/icecoder-ssl /etc/nginx/sites-enabled/
ln -s /etc/nginx/sites-available/grafana-ssl /etc/nginx/sites-enabled/
echo "SSL frontends enabled."


echo "Restarting nginx ..."
systemctl restart nginx
echo "Done."
