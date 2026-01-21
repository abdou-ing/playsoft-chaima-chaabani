variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "network_name" {
  default = "nw-chaima"
}

variable "ssh_key_name" {
  default = "hzn_shen"
}

variable "location" {
  default = "hel1"
}

variable "image" {
  default = "ubuntu-22.04"
}

variable "bastion_type" {
  default = "cx23"
}

variable "jump_type" {
  default = "cx23"
}

variable "bastion_ip" {
  default = "10.40.0.20"
}

variable "jump_ip" {
  default = "10.40.0.21"
}
