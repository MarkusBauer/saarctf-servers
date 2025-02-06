data "hcloud_image" "checker" {
  most_recent   = true
  with_selector = "name=checker"
}

resource "hcloud_server" "checker" {
  name        = "checker"
  image       = data.hcloud_image.checker.id
  server_type = var.server_type
  datacenter  = var.datacenter
  ssh_keys    = var.orga_ssh_keys
  keep_disk   = false
  lifecycle {
    ignore_changes = [image, datacenter]
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  network {
    network_id = var.network.id
    ip         = "10.32.250.${3 + var.checker_id}"
  }
}
