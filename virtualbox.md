Virtualbox Servers
==================

Virtualbox servers can be used to test the infrastructure. They are not meant for production use.

To setup a Virtualbox-based test environment, you can mainly follow the [Playbook](playbook.md).
We collect all differences here.

Find the [ssh keys here](sshkeys/saarctf_server) ([public key](sshkeys/saarctf_server.pub)) to access your servers.



Differences to Hetzner Playbook
-------------------------------
### Before the CTF
Instead of creating a new config, you can use the `test` configuration.

### Preparations
- Before building the images, you need a plain debian installation: `cd debian ; packer build buster.json`.
  If the CD image can't be fetched, you most likely need to update the Debian subversion (`debian_version` on top of `debian/buster.json`).
- When building server images, use `-only=virtualbox-ovf` instead of `-only=hcloud`.
- Use a Virtualbox host-only network instead of Hetzner networks. By default use `vboxnet1`. 
  Configuration: IP `10.32.251.1`, mask `255.255.0.0`, DHCP server enabled, smallest IP `10.32.250.10`, largest IP `10.32.250.250`.
- Skip the route configuraton, that already happens in Virtualbox installation script.
- Use `/etc/hosts` on your host to configure the domains:
  ```
  10.32.250.2   scoreboard.ctf.saarland
  10.32.250.2   cp.ctf.saarland
  10.32.250.1   vpn.ctf.saarland
  ``` 

#### Configure Services
- If you don't have real services with real checker scripts, you can use the demo checkers. 
  Leave `checker_script_dir` `NULL` and set `checker_script` to one of:
  - `checker_runner:demo_checker:WorkingService`  (always online)
  - `checker_runner:demo_checker:FlagNotFoundService` (store succeeds, but retrieve fails)
  - `checker_runner:demo_checker:OfflineService`  (always offline)
  - `checker_runner:demo_checker:TimeoutService`  (takes 20sec to complete)
  - `checker_runner:demo_checker:BlockingService` (blocking socket operation)
  - `checker_runner:demo_checker:CrashingService` (unhandled exception)
  - `checker_runner:demo_checker:SegfaultService` (segfaults the worker process)
  - `checker_runner:demo_checker:OOMService`      (allocates too much memory)
- Services are normally checked only for teams with active VPN connections. If you want to use these mocked services, use one of these tricks:
  - Set `dispatcher_check_vpn_status` to `true` in the config json.
  - Use `UPDATE teams SET vpn_connected=TRUE;` with `~/postgres-psql.sh` on controller.
