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

source "libvirt" "basis" {
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
    name  = "basis"

    source {
      type = "external"
      urls = [
        "https://cloud.debian.org/images/cloud/bookworm/20230802-1460/debian-12-generic-amd64-20230802-1460.qcow2"
      ]
      checksum = "b93f128b9ace828c7656597e462c03ea614a6635cd497c06904e8348385ded10cf43fadf0a427dde9f1ff5417f3bad37ed51d966c948ffed54f0f2e8eec599ae"
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
              name              = "root"
              lock_passwd       = false
              plain_text_passwd = var.vm_root_password
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

source "hcloud" "basis" {
  token           = "${ var.hcloud_token }"
  image           = "debian-12"
  snapshot_name   = "basis-{{timestamp}}"
  snapshot_labels = {
    name = "basis"
  }
  location     = "fsn1"
  server_type  = "cpx11"
  ssh_username = "root"
}

build {
  sources = [
    "source.libvirt.basis",
    "source.hcloud.basis"
  ]

  provisioner "ansible" {
    playbook_file       = "basis/playbook.yml"
    user                = "root"
    use_proxy           = false
    keep_inventory_file = true
    ansible_env_vars    = [
      "CONFIG_SUBDIR=${ var.config_subdir }",
      "CONFIG_GIT_REPO=${ var.config_git_repo }",
      "GAMESERVER_GIT_REPO=${ var.gameserver_git_repo }",
      "SSH_GIT_PRIVATE_KEY=${ var.ssh_git_private_key }",
      "SSH_GIT_PUBLIC_KEY=${ var.ssh_git_public_key }",
      "SSH_VULNBOX_PRIVATE_KEY=${ var.ssh_vulnbox_private_key }",
      "SSH_VULNBOX_PUBLIC_KEY=${ var.ssh_vulnbox_public_key }",
    ]
  }
}
