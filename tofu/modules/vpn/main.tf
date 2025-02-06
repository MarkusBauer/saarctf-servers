data "hcloud_image" "vpn" {
  most_recent   = true
  with_selector = "name=vpn"
}

data "hcloud_primary_ip" "vpn_ip" {
  name = "vpn"
}

resource "hcloud_server" "vpn" {
  name        = "vpn"
  image       = data.hcloud_image.vpn.id
  server_type = var.server_type
  datacenter  = var.datacenter
  ssh_keys    = var.orga_ssh_keys
  keep_disk   = true
  lifecycle {
    ignore_changes = [image, datacenter]
  }

  public_net {
    ipv4_enabled = true
    ipv4         = data.hcloud_primary_ip.vpn_ip.id
    ipv6_enabled = false
  }

  network {
    network_id = var.network.id
    ip         = "10.32.250.1"
  }
}
