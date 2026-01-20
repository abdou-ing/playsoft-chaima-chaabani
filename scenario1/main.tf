# Récupère le réseau privé existant
data "hcloud_network" "private_network" {
  name = "nw-chaima"
}

# Reference existing SSH key in Hetzner Cloud (chaima_pubkey)
data "hcloud_ssh_key" "chaima_key" {
  name = "chaima_pubkey"
}

# Firewall minimal : SSH + HTTP (ajoute HTTPS si tu veux)
resource "hcloud_firewall" "jumpserver_firewall" {
  name = "firewall-jumpserver-chaima"

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow SSH"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow HTTP"
  }

  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow HTTPS"
  }

  
}

# Serveur JumpServer
resource "hcloud_server" "public-jumpserver-chaima" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.server_location
  image       = var.server_image
  ssh_keys    = [data.hcloud_ssh_key.chaima_key.id]
  firewall_ids = [hcloud_firewall.jumpserver_firewall.id]

  # IP privée dans le réseau existant
  network {
    network_id = data.hcloud_network.private_network.id
    ip         = "10.40.0.10"
  }

  # Attribution automatique d'une IP publique
  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  user_data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true

    runcmd:
      - apt-get update
      - apt-get install -y curl wget sudo ca-certificates gnupg lsb-release docker.io docker-compose
      - systemctl enable docker
      - systemctl start docker
      - curl -sSL https://github.com/jumpserver/jumpserver/releases/latest/download/quick_start.sh | bash

  EOF
}

# Affiche l'IP publique pour accéder depuis Internet
output "jumpserver_public_ip" {
  value = hcloud_server.public-jumpserver-chaima.ipv4_address
}



