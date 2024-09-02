variable "vm_root_password" {
  type = string
}

# These keys are copied to /root/.ssh in the basic image
# They are (presumably) authorized to pull from our gitlab
variable "ssh_git_private_key" {
  type = string
}

variable "ssh_git_public_key" {
  type = string
}

# Sources
variable "config_git_repo" {
  type = string
}

variable "config_subdir" {
  type = string
}

variable "gameserver_git_repo" {
  type = string
}

variable "hcloud_token" {
  type = string
}

variable "ssh_vulnbox_private_key" {
  type = string
}

variable "ssh_vulnbox_public_key" {
  type = string
}
