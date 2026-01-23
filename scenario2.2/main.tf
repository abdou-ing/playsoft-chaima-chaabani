
data "hcloud_network" "net" {
  name = var.network_name
}

data "hcloud_ssh_key" "key" {
  name = var.ssh_key_name
}
resource "hcloud_network_subnet" "subnet" {
  network_id   = data.hcloud_network.net.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.40.0.16/28"  # ⚠ doit inclure l'IP de jumpserver et bastion
}

module "bastion" {
  source      = "./modules/bastion-host"
  name        = "hzn-bastion-chaima"
  image       = var.image
  server_type = var.bastion_type
  location    = var.location
  ip          = var.bastion_ip
  network_id  = data.hcloud_network.net.id
  ssh_key_id  = data.hcloud_ssh_key.key.id
  hcloud_token = var.hcloud_token
  network_name = var.network_name
  subnet_id   = hcloud_network_subnet.subnet.id 
  ssh_key_name = var.ssh_key_name
}

module "jumpserver" {
  source      = "./modules/JumpServer"
  name        = "hzn-jumpserver-chaima"
  image       = var.image
  server_type = var.jump_type
  location    = var.location
  ip          = var.jump_ip
  network_id  = data.hcloud_network.net.id
  ssh_key_id  = data.hcloud_ssh_key.key.id
  hcloud_token = var.hcloud_token
  network_name = var.network_name
  subnet_id   = hcloud_network_subnet.subnet.id 
  ssh_key_name = var.ssh_key_name
}
