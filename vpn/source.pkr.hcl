packer {
  required_plugins {
    sshkey = {
      version = ">= 1.0.1"
      source  = "github.com/ivoronin/sshkey"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
    libvirt = {
      version = ">= 0.5.0"
      source  = "github.com/thomasklein94/libvirt"
    }
    hcloud = {
      source  = "github.com/hashicorp/hcloud"
      version = "~> 1"
    }
  }
}

data "sshkey" "install" {

}

source "libvirt" "vpn" {
  libvirt_uri      = "qemu:///system"
  shutdown_timeout = "2m"
  shutdown_mode    = "acpi"
  vcpu             = 2
  memory           = 1024

  network_interface {
    type  = "managed"
    alias = "communicator"
  }

  # https://developer.hashicorp.com/packer/plugins/builders/libvirt#communicators-and-network-interfaces
  communicator {
    communicator         = "ssh"
    ssh_username         = "root"
    ssh_private_key_file = data.sshkey.install.private_key_path
  }
  network_address_source = "lease"

  volume {
    alias = "artifact"
    pool  = "default"
    name  = "vpn"

    source {
      type   = "backing-store"
      pool   = "default"
      volume = "basis"
    }

    capacity = "10G"
    bus      = "sata"
    format   = "qcow2"
  }

  volume {
    pool = "default"
    source {
      type      = "cloud-init"
      user_data = format("#cloud-config\n%s", yamlencode(
        {
          users = [
            {
              name                = "root"
              lock_passwd         = false
              plain_text_passwd   = var.vm_root_password
              # TODO: Replace this with public keys from relevant people instead of a keypair committed to git
              ssh_authorized_keys = [
                data.sshkey.install.public_key,
              ]
            }
          ]
        }))
    }
    bus = "sata"
  }
}

source "hcloud" "vpn" {
  token        = "${ var.hcloud_token }"
  image_filter {
    most_recent   = true
    with_selector = ["name==basis"]
  }
  snapshot_name = "vpn-{{timestamp}}"
  snapshot_labels = {
    name = "vpn"
  }
  location     = "fsn1"
  server_type  = "cpx11"
  ssh_username = "root"
}

build {
  sources = [
    "source.libvirt.vpn",
    "source.hcloud.vpn"
  ]

  provisioner "ansible" {
    playbook_file       = "vpn/playbook.yml"
    user                = "root"
    use_proxy           = false
    keep_inventory_file = true
    ansible_env_vars    = [
      "CONNTRACK_ACCOUNTING_GIT_REPO=${ var.conntrack_accounting_git_repo }",
      "SAARCTF_CONFIG_DIR=/opt/config/${ var.config_subdir }",
      "PARTICIPANTS_HCLOUD_TOKEN=${ var.participants_hcloud_token }"
    ]
  }
}