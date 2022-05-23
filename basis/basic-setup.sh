#!/usr/bin/env bash

set -e

is_virtualbox() {
  (dmidecode -t system|grep 'Manufacturer\|Product' | grep -q 'VirtualBox')
  return $?
}


export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y
apt-get install -y \
    sudo nano htop git bash-completion ntp ntpdate virt-what cloud-initramfs-growroot gnupg gnupg2 \
    python3 python3-dev python3-pip python3-setuptools python3-wheel \
    python3-redis python3-psycopg2 \
    python3-flask python3-flask-api python3-flask-migrate python3-flask-restful \
    python3-apscheduler python3-sqlalchemy \
    python3-setproctitle python3-filelock python3-htmlmin python3-ujson \
    python3-requests python3-venv python3-virtualenv \
    python3-tornado python3-babel  \
    openvpn iptables iptables-persistent net-tools procps libbpf-dev iftop \
    postgresql-client redis-tools \
    psutils curl wget screen rsync p7zip-full tcpdump man silversearcher-ag \
    libpq-dev python3-dev postgresql-server-dev-all zlib1g-dev libjpeg-dev libpng-dev build-essential
apt-get install --no-install-recommends -y at prometheus-node-exporter
apt-get clean
# outdated: python3-flask-sqlalchemy 
systemctl enable prometheus-node-exporter


# Configure Influx / Telegraf repository
wget -qO- https://repos.influxdata.com/influxdb.key | apt-key add -
if wget "https://repos.influxdata.com/debian/dists/$(lsb_release -cs)/stable/" -O/dev/null -q; then
  echo "deb https://repos.influxdata.com/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/influxdb.list
else
  echo "deb https://repos.influxdata.com/debian buster stable" > /etc/apt/sources.list.d/influxdb.list
  echo "Warning: InfluxDB release for distribution $(lsb_release -cs) not found, using Debian Buster fallback."
fi


# Virtualbox only - configure network adapter
is_virtualbox && (
    echo 'allow-hotplug enp0s8' >> /etc/network/interfaces.d/vboxnet
    echo 'iface enp0s8 inet dhcp' >> /etc/network/interfaces.d/vboxnet
) || true


# Add key to SSH server
mkdir -p /root/.ssh
test -z "$SSH_AUTHORIZED_KEY" || echo "$SSH_AUTHORIZED_KEY" >> /root/.ssh/authorized_keys
test -z "$SSH_AUTHORIZED_KEY_ADDRESS" || wget -q -O- "$SSH_AUTHORIZED_KEY_ADDRESS" >> /root/.ssh/authorized_keys || true
chmod 0600 /root/.ssh/*

# Clone repositories
git clone "$CONFIG_GIT_REPO" /opt/config
git clone "$GAMESERVER_GIT_REPO" /opt/gameserver
git -C /opt/gameserver submodule init
git -C /opt/gameserver submodule update
git -C /opt/gameserver config receive.denyCurrentBranch warn

# Configure saarCTF
cat <<EOF > /etc/profile.d/env.sh
#!/usr/bin/env bash
export SAARCTF_CONFIG_DIR=/opt/config/$CONFIG_SUBDIR
export FLASK_APP=/opt/gameserver/controlserver/app.py
EOF
echo "SAARCTF_CONFIG_DIR=/opt/config/$CONFIG_SUBDIR" >> /etc/environment

# Install missing python dependencies (flower etc)
pip3 install -r /opt/gameserver/requirements.txt


# install rmate (for me)
curl -o /usr/local/bin/rmate https://raw.githubusercontent.com/aurora/rmate/master/rmate
sudo chmod +x /usr/local/bin/rmate

# configure git
git config --global user.name "saarctf server"
git config --global user.email "saarctf@saarsec.rocks"
git config --global pull.rebase true

# configure htop
mkdir -p /root/.config/htop
mv /tmp/htoprc /root/.config/htop/


# Virtualbox only - cleanup disk
is_virtualbox && sh -c 'dd if=/dev/zero of=/var/tmp/bigemptyfile bs=4096k ; rm /var/tmp/bigemptyfile ; echo OK' || true

