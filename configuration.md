Configuration
=============

For configuration you should prepare:
1. a *configuration git repository* hosted on your private git server
2. two pairs of SSH keys: one to access the git repository, one to access the final servers
3. a set of internal and external passwords
4. Domains for your VPN gateway, scoreboard and control panel. 


## Configuration Repository
Your git repository should be structured like this, one folder per CTF:
```
configuration.git
 |-- <your-ctf-2020>
 |   |- config.json
 |   \- htpasswd
 |-- <your-ctf-test>
 |   |- config.json
 |   \- htpasswd
...
```
- `config.json` is a **gameserver configuration** [(sample here)](https://github.com/MarkusBauer/saarctf-gameserver/blob/master/config.sample.json), or see our [saarCTF 2020 real-world configuration](./gameserver-config-sample.json).
  Credentials within this file should not change after server setup.
- `htpasswd` should contain credentials for your CTF administrators (required to access the control panel).


## Packer configuration
Create a file `config.json` in this repository's root, starting with the content of [config.sample.json](config.sample.json). 
Later use this file in all packer commands with `-var-file ../config.json`. 

**Required Packer configuration options:**
- `config_git_repo`: Your configuration repository
- `config_subdir`: The directory in your configuration repository you want to use (`<your-ctf-2020>` etc in the example above)
- `ssh_git_private_key`: (relative) path to a SSH key with access to the configuration repository (will become server's `id_rsa`)
- `ssh_git_public_key`: (relative) path to a SSH public key with access to the configuration repository (will become server's `id_rsa.pub`)
- `ssh_known_hosts_file`: (relative) path to a `known_hosts` file (avoid confirmation of your git SSH server's public key)

- `ssh_authorized_key`: public SSH key from admin (`"ssh-rsa ..."`)
- `ssh_authorized_private_keyfile`: (relative) path to private SSH keyfile (used to connect with the server during setup)
- `vm_root_password`: `root` user's password on the server (required for Virtualbox, optional for Cloud servers)

- `grafana_username`: Username for the installed Grafana dashboard
- `grafana_password`: Password for the installed Grafana dashboard
- `htaccess_username`: A valid username from the `htaccess` file for your CTF 
- `htaccess_password`: A valid password from the `htaccess` file for your CTF
- `icecoder_password`: Password for the installed IceCoder installation
- `postgresql_replication_password`: (Internal) replication password for PostgreSQL, used for backup servers. 


**Optional Packer configuration options:**
- `gameserver_git_repo`: A custom git remote for the gameserver repository (for example your private, branded fork)
- `conntrack_accounting_git_repo`: A custom git remote for the conntrack_accounting tools
- `ssh_authorized_key_address`: A http(s) url with additional SSH public keys. Will be installed like `wget $URL -O- >> /root/.ssh/authorized_keys`
