
resource "hcloud_firewall" "bastion_fw" {
  name = "fw-bastion"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0"]
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "bastion" {
  name        = var.name
  image       = var.image
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [var.ssh_key_id]
  firewall_ids = [hcloud_firewall.bastion_fw.id]

  network {
    network_id = var.network_id
    
    ip         = var.ip
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  user_data = file("${path.module}/cloud-init.yml")
}
