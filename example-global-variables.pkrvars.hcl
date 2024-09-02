config_git_repo               = "...your-config-repo..."
config_subdir                 = "test"
gameserver_git_repo           = "https://github.com/MarkusBauer/saarctf-gameserver"
conntrack_accounting_git_repo = "https://github.com/MarkusBauer/saarctf-conntrack-accounting"

# Used for git pull in the infra vms
ssh_git_private_key           = "../saarctf-configuration/2023-test/ssh-keys/saarctf_repos"
ssh_git_public_key            = "../saarctf-configuration/2023-test/ssh-keys/saarctf_repos.pub"
# Used for vulnbox access
ssh_vulnbox_private_key         = "../saarctf-configuration/2023-test/ssh-keys/saarctf_vulnbox"
ssh_vulnbox_public_key          = "../saarctf-configuration/2023-test/ssh-keys/saarctf_vulnbox.pub"

vm_root_password                = ""
postgresql_replication_password = ""
grafana_username                = "saarsec"
grafana_password                = ""
icecoder_password               = ""
htaccess_username               = "saarsec"
# This currently needs to be manually synced with htpasswd in configuration,
# We should instead hash it via ansible when building the VMs
htaccess_password               = ""
hcloud_token                    = ""
participants_hcloud_token       = ""
