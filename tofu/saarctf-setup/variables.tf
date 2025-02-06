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

variable "hcloud_token" {
  type = string
  sensitive = true
}

variable "location" {
  type = string
  default = "nbg1"
}

variable "datacenter" {
  type = string
  default = "nbg1-dc3"
}

variable "checker_server_type" {
  type = string
  default = "cx22"
}

variable "controller_server_type" {
  type = string
  default = "cx22"
}

variable "vpn_server_type" {
  type = string
  default = "cx22"
}

variable "pcap_vol_size" {
  type = number
  default = 10
}

