variable "hcloud_token" {
	type      = string
	sensitive = true
}
variable "name" {}
variable "image" {}
variable "server_type" {}
variable "location" {}
variable "network_id" {}
variable "ip" {}
variable "ssh_key_id" {}

variable "network_name" {}
variable "subnet_id" {}
variable "ssh_key_name" {}
