provider "hcloud" {
  token = var.hcloud_token
}

module "network" {
  source = "../modules/network"
}

module "controller" {
  source        = "../modules/controller"
  orga_ssh_keys = var.orga_ssh_keys
  datacenter    = var.datacenter
  server_type   = var.controller_server_type
  network       = module.network
}

module "checker" {
  source        = "../modules/checker"
  orga_ssh_keys = var.orga_ssh_keys
  datacenter    = var.datacenter
  server_type   = var.checker_server_type
  checker_id    = 1
  network       = module.network
}

module "vpn" {
  source        = "../modules/vpn"
  orga_ssh_keys = var.orga_ssh_keys
  datacenter    = var.datacenter
  server_type   = var.vpn_server_type
  network       = module.network
}

resource "hcloud_volume" "pcaps" {
  name      = "pcaps"
  size      = var.pcap_vol_size
  location  = var.location
  automount = false
  format    = "ext4"
}

resource "hcloud_volume_attachment" "pcaps" {
  volume_id = hcloud_volume.pcaps.id
  server_id = module.vpn.id
  automount = false
}
