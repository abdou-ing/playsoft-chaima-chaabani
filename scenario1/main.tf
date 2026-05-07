# Récupère le réseau privé existant
data "hcloud_network" "private_network" {
  name = "nw-chaima"
}

# Reference existing SSH key in Hetzner Cloud (chaima_pubkey)
data "hcloud_ssh_key" "chaima_key" {
  name = "chaima_pubkey"
}

# Firewall minimal : SSH + HTTP 
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
resource "hcloud_primary_ip" "jumpserver_ipv4" {
  name          = "pip-jumpserver-chaima"
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
  location      = var.server_location
}

resource "hcloud_server" "public-jumpserver-chaima" {
  name         = var.server_name
  server_type  = var.server_type
  location     = var.server_location
  image        = var.server_image
  ssh_keys     = [data.hcloud_ssh_key.chaima_key.id]
  firewall_ids = [hcloud_firewall.jumpserver_firewall.id]

  # IP privée dans le réseau existant
  network {
    network_id = data.hcloud_network.private_network.id
    ip         = "10.40.0.10"
  }

  # Attribution automatique d'une IP publique
  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.jumpserver_ipv4.id
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

resource "null_resource" "configure_jumpserver" {
  count = var.enable_ansible_post_apply ? 1 : 0

  triggers = {
    server_ipv4 = hcloud_server.public-jumpserver-chaima.ipv4_address
  }

  # ÉTAPE 1 : Health check uniquement
  provisioner "local-exec" {
    command = <<-EOT
      echo "Attente du démarrage de JumpServer..."
      READY=0
      for i in $(seq 1 40); do
        STATUS=$(curl -s -o /dev/null -w "%%{http_code}" \
          http://${hcloud_primary_ip.jumpserver_ipv4.ip_address}/api/v1/health/ \
          --connect-timeout 5 2>/dev/null || echo "000")
        echo "Tentative $i/40 — HTTP status: $STATUS"
        if [ "$STATUS" = "200" ] || [ "$STATUS" = "401" ]; then
          echo "JumpServer est prêt ✓"
          READY=1
          break
        fi
        sleep 15
      done
      if [ "$READY" -ne 1 ]; then
        echo "JumpServer non prêt après 40 tentatives" >&2
        exit 1
      fi
    EOT
  }

  # ÉTAPE 2 : Lancer Ansible directement
  provisioner "local-exec" {
    working_dir = "${path.root}/../../ansible"
    command     = <<-EOT
      set -e
      ansible-playbook add_public_server.yml
      ansible-playbook create_private_server.yml
      ansible-playbook create_system_admin_user.yml
      ansible-playbook create_user_session.yml
      ansible-playbook autoriser_utilisateur.yml
    EOT
  }

  depends_on = [hcloud_server.public-jumpserver-chaima]
}