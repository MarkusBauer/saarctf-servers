saarCTF Servers
===============

See also: [Hetzner Cloud Playbook](playbook.md), [Virtualbox Playbook](virtualbox.md).


This repository contains setup scripts for all servers required to host an attack-defense CTF with the saarCTF framework.
It consists of three server types: 

1. **Gameserver** (*Controller*): Databases, Scoreboard, Flag submitter, Control panels, Monitoring
2. **VPN**: OpenVPN, Routing, Firewall, Anonymization
3. **Checker**: Checker script runner (multiple instances possible)

You need a git configuration repository and a local `config.json` configuration for the build process. 
See [Configuration](configuration.md) for details.


To prepare server images (in VirtualBox for tests):
- `cd debian ; packer build -var-file=../config.json -only=virtualbox-iso bullseye.json`
- `cd basis ; packer build -var-file=../config.json -only=virtualbox-ovf basis.json`
- `cd controller ; packer build -var-file=../config.json -only=virtualbox-ovf controller.json`
- `cd vpn ; packer build -var-file=../config.json -only=virtualbox-ovf vpn.json`
- `cd checker ; packer build -var-file=../config.json -only=virtualbox-ovf checker.json`


By default these IPs are used:
- VPN Gateway: `10.32.250.1`
- Gameserver: `10.32.250.2`
- Checker server: `10.32.250.3+`
- Team N: `10.32.N.0/24`
- Nop-Team: `10.32.1.0/24`
- Organizer network: `10.32.0.0/24`



------------------------------------------------

## 1. Gameserver
Interesting commands: `update-server` (pull updates and rebuild things). 

Checker scripts belong on this machine (`/home/saarctf/checkers`, owned by user `saarctf`).

CTF Timer needs manual start (on exactly one machine), new hosts must be manually added to Prometheus for monitoring (`/root/prometheus-add-server.sh <ip>`). 

A bunch of interesting scripts are in `/root`, check them out. 

This image can be reconfigured to fill in almost any particular role, using the scripts in `/root` to disable some components. We think of backup servers (databases to slaves replicating original databases), dedicated management / monitoring server (db to slave, disable monitoring on original host) or dedicated scoreboard / submitter server (db off, monitoring off, `systemctl start scoreboard`). 


### 1.1 Databases
Postgresql (:5432), Redis (:6379), RabbitMQ. 


### 1.2 Control Panel
Flask app running under uwsgi / user saarctf. Nginx frontend.

- `http://<ip>:8080/`
- Restart: `systemctl restart uwsgi`
- Logs: `/var/log/uwsgi/app/controlserver.log`


### 1.3 Flower (celery control panel)
Tornado app (systemd), Nginx frontend.
- `http://<ip>:8081/` / `http://127.0.0.1:20000`
- Restart: `systemctl restart flower`
- Logs: `/var/log/flower.log`


### 1.4 ICEcoder
PHP app served by Nginx / running as saarctf.
- `http://<ip>:8082/`
- Restart: `systemctl restart php7.3-fpm nginx`
- Logs: `/opt/icecoder/data/error.log`, `/var/log/nginx/error.log`, `/var/log/fpm-php.www.log`, `/var/log/php7.3-fpm.log`


### 1.5 Scoreboard
Static folder with files, served by nginx.
- `http://<ip>/`
- Restart: `systemctl restart nginx`
- Logs: `/var/log/nginx/access.log` and `/var/log/nginx/error.log`
- Config: `/etc/nginx/sites-available/scoreboard`

The scoreboard is automatically created if the CTF timer is running on this machine. If not use the scoreboard daemon instead (`systemctl start scoreboard`, but not in parallel with the CTF timer). 


### 1.6 CTF Timer
*Needs manual start*

Triggers time-based events (new round, scoreboard rebuild, start/stop of CTF). Exactly one instance on one server must run at any time.
- Start: `systemctl start ctftimer`
- Restart: `systemctl restart ctftimer`
- Logs: `/var/log/ctftimer.log` (interesting messages usually shown in controlpanel dashboard)


### 1.7 Flag Submission Server
C++ application that receives flags from teams. 
- `nc <ip> 31337`
- Restart: `systemctl restart submission-server`
- Rebuild/Update: `update-server`
- Logs: `/var/log/submission-server.log`


### 1.8 Prometheus Monitoring
Monitors itself, grafana and localhost by default, other servers should be manually added using `/root/prometheus-add-server.sh <ip>`. Results can be seen in Grafana. 
- `http://localhost:9090/`
- Restart: `systemctl restart prometheus`
- Logs: `journalctl -u prometheus`


### 1.9 Grafana Dashboard
Configured to display stats from database and prometheus. 
- `http://<ip>:3000/`
- Restart: `systemctl restart grafana`
- Logs: `/var/log/grafana/grafana.log`
- Config: `/etc/grafana/grafana.ini`





------------------------------------------------

## 2. VPN-Server
*tcpdump needs manual start / stop*

Runs many OpenVPN instances and network management. 
OpenVPN configuration files should be (re)built at least once on this machine. 


### 2.1 OpenVPN servers
Three servers per team, managed by systemd. Service name is:
1. `vpn@teamXYZ` (tunX) for the single, self-hosted VPN (whole /24 in one connection)
2. `vpn2@teamXYZ-cloud` (tun100X) for the cloud-hosted team members endpoint (upper /25, multiple connections possible)
3. `vpn@teamXYZ-vulnbox` (tun200X) for the single, cloud-hosted vulnbox connection (/30 for cloud box, config not given to players)

Activation rules:
1. `vpn@teamX-vulnbox` is always active (players can't mess too much with it, except by booting a vulnbox)
2. If `vpn@teamX-vulnbox` is connected, team-hosted vpn `vpn@teamX` is down (avoiding conflicts with team members using the old config)
3. If `vpn@teamX` is connected, cloud-hosted player vpn `vpn2@teamX-cloud` is down (avoid both configs being used at the same time)

- Server for Team X listening on `<ip>:10000+X / <ip>:12000+X / <ip>:1400+X (udp)`
- Interface of Team X: `tunX` / `tun100X` / `tun200X`
- Start one / all: `systemctl start vpn@teamX` / `systemctl start vpn`
- Restart one / all: `systemctl restart vpn@teamX` / `systemctl restart vpn vpn@\*`
- Stop one / all: `systemctl stop vpn@teamX` / `systemctl stop vpn vpn@\*`
- Logs: `/var/log/openvpn/output-teamX.log` and `/var/log/openvpn/openvpn-status-teamX.log`


### 2.2 Traffic Statistics Collector
Writes traffic summary to database.
- Restart: `systemctl restart trafficstats`
- Logs: `/var/log/trafficstats.log`


### 2.3 Firewall
Based on IPTables. 
Edit `/opt/gameserver/vpn/iptables.sh` if you need to change something permanently. 
On restart, `INPUT` and `FORWARD` chains are replaced. 
Inserts rules for NAT and TCP Timestamp removal. 
- Restart: `systemctl restart firewall`
- Logs: `/var/log/firewall.log`


### 2.4 Firewall Manager
Inserts rules into IPTables that open/close VPN or ban single teams. 
- Restart: `systemctl restart manage-iptables`
- Logs: `/var/log/firewall.log`


### 2.5 TCPDump
*Needs manual start*

Captures traffic: game traffic (between gameservers and teams) and team traffic (between teams).
- Start: `systemctl start tcpdump-game tcpdump-team`
- Restart: `systemctl restart tcpdump-game tcpdump-team`
- Logs: `/var/log/tcpdump.log`


### 2.6 VPNBoard
Website that displays connection status of VPN connections and tests connectivity using ping.
Website is finally served by an nginx.
Includes a background worker (service `vpnboard-celery`).
- Restart: `systemctl restart vpnboard`
- Logs: `/var/log/vpnboard.log`




------------------------------------------------

## 3. Checker-Server
Runs only a Celery Worker. 
No checker scripts need to be placed on this machine. 

*Needs manual start*
because each celery worker needs an unique name.

**After creation** run `celery-configure <SERVER-NUMBER>`. 
From now on, the celery worker will start on boot. 

- Configuration: `/etc/celery.conf`
- Restart: `systemctl restart celery`
- Logs: `/var/log/celery/XYZ.log`

Manual worker invocation: 
- `screen -R celery`
- `celery-run <unique-hostname> <number-of-processes>`

