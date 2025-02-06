terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
  required_version = ">= 1"
}

variable "orga_ssh_keys" {
  type = list(string)
}

variable "network" {
  type = object({
    id = string
  })
}

variable "datacenter" {
  type = string
}

variable "server_type" {
  type = string
}
