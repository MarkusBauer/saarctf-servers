# Test-Setup

We test servers in libvirt, see [libvirt-test-setup/README.md](libvirt-test-setup/README.md).

## Configure Services
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