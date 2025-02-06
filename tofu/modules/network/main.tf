resource "hcloud_network" "network" {
  name     = "saarctf"
  ip_range = "10.32.0.0/11"
}

resource "hcloud_network_subnet" "infra_subnet" {
  network_id   = hcloud_network.network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.32.250.0/24"
}

locals {
  routes = [
    "10.32.0.0/17",
    "10.32.128.0/18",
    "10.32.192.0/19",
    "10.33.0.0/16",
    "10.48.0.0/15",
  ]
}

resource "hcloud_network_route" "route" {
  network_id  = hcloud_network.network.id
  for_each    = toset(local.routes)
  destination = each.value
  gateway     = "10.32.250.1"
}

