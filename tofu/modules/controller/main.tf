data "hcloud_primary_ip" "controller_ip" {
  name = "controller"
}

data "hcloud_image" "controller" {
  most_recent   = true
  with_selector = "name=controller"
}

resource "hcloud_server" "controller" {
  name        = "controller"
  image       = data.hcloud_image.controller.id
  server_type = var.server_type
  datacenter  = var.datacenter
  ssh_keys    = var.orga_ssh_keys
  keep_disk   = false
  lifecycle {
    ignore_changes = [image, datacenter]
  }

  public_net {
    ipv4_enabled = true
    ipv4         = data.hcloud_primary_ip.controller_ip.id
    ipv6_enabled = false
  }

  network {
    network_id = var.network.id
    ip         = "10.32.250.2"
  }
}
