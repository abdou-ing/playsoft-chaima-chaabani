
resource "hcloud_firewall" "jump_fw" {
  name = "fw-jump"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["10.40.0.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["10.40.0.0/24"]
  }
}

resource "hcloud_server" "jumpserver" {
  name        = var.name
  image       = var.image
  server_type = var.server_type
  location    = var.location
  ssh_keys    = [var.ssh_key_id]
  firewall_ids = [hcloud_firewall.jump_fw.id]

  network {
    network_id = var.network_id
    ip         = var.ip
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  user_data = file("${path.module}/cloud-init.yml")
}
