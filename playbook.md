# saarCTF server playbook

This guide will create ready-to-go servers hosted on [Hetzner Cloud](https://www.hetzner.de/cloud). Account there (and services) are required.
If you want a local test environment check out the [libvirt instructions](libvirt-test-setup/README.md).

### Before the CTF

If you are following the [general playbook](https://gitlab.saarsec.rocks/saarctf/wiki/-/wikis/Playbook), you should already have done these steps.

1. Create a new folder in the configuration repository, copying from last year's iteration. Adjust settings if necessary.
2. Setup the saarctf registration website somewhere ("registration server", saarsec server for example).
3. Checkout config repo on registration server, point the registration website there.

### Preparations (a few days before start)

We will now prepare server images and setup VPN servers (to test against).
Step 1-7 is currently performed by Terraform.

1. Open `global-variables.pkrvars.hcl` in this repository and edit the key `config_subdir` to the name of your new config repo subfolder (created in the very first step).
   Use [example-global-variables.pkrvars.hcl](example-global-variables.pkrvars.hcl) as a basis if this file does not yet exist.
   If necessary, also rotate the passwords and SSH keys.
2. Use [packer](https://www.packer.io/) to build all images (Hetzner version only). Run these commands (basis build before other builds):
   ```
   export HCLOUD_TOKEN=<...>
   packer init basis
   packer build -var-file global-variables.pkrvars.hcl -only=hcloud.basis basis
   packer build -var-file global-variables.pkrvars.hcl -only=hcloud.basis controller
   packer build -var-file global-variables.pkrvars.hcl -only=hcloud.basis vpn
   packer build -var-file global-variables.pkrvars.hcl -only=hcloud.basis checker
   ```
   After this step your Hetzner account should have at least snapshots for controller, vpn and checker.
3. Create a new private network for the game (or reuse the old one). Configure:
   - IP Range: `10.32.0.0/11`
   - One subnet: `10.32.250.0/24`
4. Create a VPN server (first) and a Controller server (second). Use the smallest possible server type, and add both to the network (can be selected when creating a server).
5. Check the IPs of the machines from the previous step: Controller must be `10.32.250.2`, VPN should be `10.32.250.1`. If IPs are wrong remove and reattach the server from the network.
6. Add routes to the network:
   - `10.32.0.0/17` => VPN server
   - `10.32.128.0/18` => VPN server
   - `10.32.192.0/19` => VPN server
   - `10.33.0.0/16` => VPN server
   - `10.48.0.0/15` => VPN server
7. Configure the domains:
   - `vpn.ctf.saarland` should point to the public IP of VPN
   - `scoreboard.ctf.saarland` should point to the public IP of Controller
   - `cp.ctf.saarland` can point to Controller or to a failover Controller server (to be added later)
8. Let's configure SSL (saarsec only):
   1. if necessary: on saarsec server copy the certs to the configuration repo (`cp -L /etc/letsencrypt/live/ctf.saarland/* /opt/saarctf-config/certs/`) and push.
   2. Pull repo on Controller and Vpn server (in `/opt/config`)
   3. Run `~/nginx-enable-ssl.sh` on Controller and VPN server
9. Check that [https://scoreboard.ctf.saarland](https://scoreboard.ctf.saarland) and [https://vpn.ctf.saarland](https://vpn.ctf.saarland) both have meaningful output. If scoreboard bugs issue `update-server` on Controller. If Flower / RabbitMQ bug issue `~/rabbitmq-setup.sh`.
10. Enable the link to scoreboard on the saarCTF website (Django admin => Config => `SHOW_SCOREBOARD` and `SHOW_SCOREBOARD`).
11. Enable the wireguard script: `systemctl enable wireguard-sync && systemctl start wireguard-sync`
12. If you use cloud-hosting and want to auto-open the Hetzner Cloud Firewall:
    - On VPN server, edit `/etc/systemd/system/manage-hetzner-firewall.service` and insert a cloud access token
    - `systemctl enable manage-hetzner-firewall && systemctl start manage-hetzner-firewall`

#### Configure Services

Services are auto-configured during controller image build. 
If necessary, you can update them later:
`sudo -u saarctf gspython /opt/gameserver/scripts/service_update.py`

Add all service to `/root/ports.conf` on the VPN server, so that their traffic will be monitored and accounted.

#### Synchronize teams

The VPN server syncs teams automatically with a cronjob. 
If necessary, you can trigger this manually: `python3 scripts/sync_teams.py`

### Just before the CTF

A few hours before the game starts, its time to build the real infrastructure.
The existing servers will be upscaled, redundancy and checkers will be added.
These steps involve a downtime of a few minutes, existing VPN connections will break.
What we will build:

- 1x CCX31 Controller
- 1x CX21 Backup (of controller)
- 1x CCX51 VPN Gateway
- ?x CPX41 Checker (2021 we had 1x CPX41 for all services, +1x CPX51 for Chromium)

Steps 1-7 are performed by Terraform.

1. In the cloud control panel, create a new volume (for pcaps). I suggest at least 1TB, better 2TB.
2. (*ignored for now*) Create the backup/monitoring server: Spawn a new server from the controller image, type CX21 or so, choose to have a larger disk.
3. (*ignored for now*) Once the backup server is up, run `/root/failover-set-slave.sh`
4. Shutdown VPN server and Controller server.
5. Add the Volume from (3) to the VPN server.
6. Rescale Controller and VPN server (for example to CCX31/CCX51). Start with Controller (which might need the additional disk space).
7. Mount the volume on the VPN server (follow instructions on Hetzner page). 
   Check twice it's mounted to `/mnt/pcaps`, if not: edit `/etc/fstab`, unmount and do `mount -a`.
8. Once both are up again mention restart in IRC, and check that the replication databases from the backup system are reconnecting. 
   Also check that Controller and Backup have their additional disk space (if not try `resize2fs /dev/sda1`).
9. On the VPN server start tcpdump (`systemctl start tcpdump-game tcpdump-team`) and check that the pcaps are stored on the mounted volume.
10. Start the CTF timer on the Controller server (`systemctl start ctftimer`) and check the results in dashboard. There should be no warning.
11. (*ignored for now*) On the backup server, enable the Scoreboard daemon (`systemctl start scoreboard`).
12. Create some checker servers from the checker snapshot, CPX41 or CPX51, disk doesn't matter. 
13. For each checker server:
    - Connect to each new checker server and run `celery-configure <server-number>` with a unique server number. 
    - This will already install all service dependencies. If services are not yet populated, you can repeat this step later:
      `cd /opt/gameserver ; ./run.sh scripts/service_setup_scripts.py`
    - Check that the number of threads is appropriate (in `/etc/celery.conf`), edit and restart service if necessary.
    - Check that the celery worker is connecting (in dashboard / Flower).
14. Go to the controller and backup/monitoring server. Use `/root/prometheus-add-server.sh <ip>` to add: controller server, vpn server, all checker servers.
15. Open Grafana and check that you receive data from all servers, and all are healty.
16. You could do some final tests with the NOP team here. 
    In the dashboard, you can open the network for NOP team only, under Scripts, you can test the current checker scripts.
17. Finally: Open the CTF controlpanel and set autostart and last round. Pay attention to the server's timezone.
18. Watch the countdown for the game to start...

### Key Announcement / Vulnbox Access

1. Release the key: IRC/Website/Email/Twitter/Mastodon
2. Cloud boxes become controllable by a time configured in the website. Check that that worked.
3. In dashboard, press "Open Network within Teams" (so that remote teams get access to their boxes). Now external firewall opens also for cloud boxes, and vpnboard starts pinging these boxes.
4. Check that vulnboxes come online in VPN Dashboard

### During CTF

Network opens and closes automatically. Checkers and scoring work automatically. Your job is it to monitor the game and step in if things get out of control. Some remarks:

- Checker servers can be added any time, but need the setup command described above.
- Before removing a checker server, gracefully stop the celery daemon there.
- Get familiar with the scripts in `/opt/gameserver/scripts`. They can manually trigger actions in the game (for example: repeat stuff that failed) or recalculate things (for example after SLA recalculation).
- Make a backup (database dump) before every manual change.
- If the load on the main Controller gets too high, you can move submitter and scoreboard to a dedicated machine: Boot a new controller, disable databases and monitoring there, enable the scoreboard daemon and redirect traffic.

### After the CTF

Hetzner servers cost money per hour, even if they're powered off. After the CTF it's crucial to get rid of them as fast as possible.

1. Shutdown and remove the checker servers. You shouldn't need any backup from there, except if celery-related issued occured. Remember: remove, not just power off.
2. Stop tcpdump on VPN and ctftimer on Controller.
3. Run the provided backup scripts on VPN (`backup-logs.sh`), controller and backup (`backup-all.sh`).
4. Download all backups (`/root/backups` on all machines).
5. Deploy the final scoreboard (from backup archive): upload the archive on the registration page and change `CONFIG_SCOREBOARD_URL` in the registration page config (`/etc/uwsgi/apps-available/saarctf-webpage.ini`). Spread the word and change `scoreboard.ctf.saarland` DNS entry (point it to saarsec again).
6. Take a screenshot from the Hetzner cloud console showing the accounted traffic used by all machines.
7. Remove controller and backup server.
8. Depending on your internet speed:
   - Download the pcaps from VPN server, then remove VPN server
   - Remove VPN server, remount the volume to a cheap server, and download pcaps from there.
9. After you validated the integrity of the pcaps, remove the volume (also billed hourly).
10. If you want you can also remove the snapshots/images.
11. Ensure no billable resources retain in the Cloud console (except the network, that's free).
12. Upload your results to CTFTime (find a JSON file in the controller backup folder).
