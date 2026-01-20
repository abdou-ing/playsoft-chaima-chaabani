
# Récupère le réseau privé existant
data "hcloud_network" "private_network" {
  name = var.private_network_name
}

# Récupère la clé SSH existante
data "hcloud_ssh_key" "chaima_key" {
  name = var.ssh_key_name
}

# Crée un subnet cloud dans le réseau (si pas déjà existant)
resource "hcloud_network_subnet" "cloud_subnet" {
  network_id   = data.hcloud_network.private_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.40.0.16/28"  # Range: 10.40.0.16 - 10.40.0.31
}
# FIREWALL POUR LE BASTION (serveur public)

resource "hcloud_firewall" "bastion_firewall" {
  name = "firewall-bastion-chaima"

  # SSH depuis Internet
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow SSH from Internet"
  }

  # HTTP pour Nginx reverse proxy
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow HTTP"
  }

  # HTTPS pour Nginx reverse proxy
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
    description = "Allow HTTPS"
  }

  # Autoriser tout le trafic sortant (NAT)
  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "any"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow all outbound TCP"
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "any"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow all outbound UDP"
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow ICMP outbound"
  }
}

# FIREWALL POUR LE JUMPSERVER PRIVÉ (pas d'IP publique)

resource "hcloud_firewall" "jumpserver_private_firewall" {
  name = "firewall-jumpserver-private-chaima"

  # SSH depuis le réseau privé uniquement
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["10.40.0.0/24"]
    description = "Allow SSH from private network"
  }

  # HTTP depuis le réseau privé (pour JumpServer web UI)
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["10.40.0.0/24"]
    description = "Allow HTTP from private network"
  }

  # HTTPS depuis le réseau privé
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["10.40.0.0/24"]
    description = "Allow HTTPS from private network"
  }

  # JumpServer utilise aussi le port 2222 pour SSH jump
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = "2222"
    source_ips  = ["10.40.0.0/24"]
    description = "Allow JumpServer SSH port from private network"
  }
}


# SERVEUR BASTION (NAT + Reverse Proxy Nginx) - PUBLIC
resource "hcloud_server" "bastion" {
  name        = "bastion-nat-nginx-chaima"
  server_type = var.bastion_server_type
  location    = var.server_location
  image       = var.server_image
  ssh_keys    = [data.hcloud_ssh_key.chaima_key.id]
  firewall_ids = [hcloud_firewall.bastion_firewall.id]

  depends_on = [hcloud_network_subnet.cloud_subnet]

  # IP privée dans le réseau existant
  network {
    network_id = data.hcloud_network.private_network.id
    ip         = var.bastion_private_ip
  }

  # IP publique activée
  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  user_data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true

    packages:
      - nginx
      - iptables-persistent
      - net-tools

    write_files:
      # Configuration Nginx reverse proxy vers JumpServer privé
      - path: /etc/nginx/sites-available/jumpserver-proxy
        content: |
          server {
              listen 80;
              server_name _;

              location / {
                  proxy_pass http://${var.jumpserver_private_ip};
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
              }
          }

      # Script pour activer le NAT (IP forwarding + masquerading)
      - path: /usr/local/bin/setup-nat.sh
        permissions: '0755'
        content: |
          #!/bin/bash
          # Activer l'IP forwarding
          echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
          sysctl -p

          # Configurer iptables pour le NAT (masquerading)
          iptables -t nat -A POSTROUTING -s 10.40.0.0/24 -o eth0 -j MASQUERADE
          iptables -A FORWARD -i ens10 -o eth0 -j ACCEPT
          iptables -A FORWARD -i eth0 -o ens10 -m state --state RELATED,ESTABLISHED -j ACCEPT

          # Sauvegarder les règles iptables
          netfilter-persistent save

    runcmd:
      # Activer la configuration Nginx
      - ln -sf /etc/nginx/sites-available/jumpserver-proxy /etc/nginx/sites-enabled/
      - rm -f /etc/nginx/sites-enabled/default
      - systemctl restart nginx
      - systemctl enable nginx

      # Configurer le NAT
      - /usr/local/bin/setup-nat.sh

  EOF
}


# SERVEUR JUMPSERVER PRIVÉ (pas d'IP publique)

resource "hcloud_server" "jumpserver_private" {
  name        = "jumpserver-private-chaima"
  server_type = var.jumpserver_server_type
  location    = var.server_location
  image       = var.server_image
  ssh_keys    = [data.hcloud_ssh_key.chaima_key.id]
  firewall_ids = [hcloud_firewall.jumpserver_private_firewall.id]

  depends_on = [hcloud_network_subnet.cloud_subnet]

  # IP privée uniquement (pas d'IP publique)
  network {
    network_id = data.hcloud_network.private_network.id
    ip         = var.jumpserver_private_ip
  }

  # PAS d'IP publique
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  user_data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true

    write_files:
      # Configuration réseau statique + DNS + route par défaut vers le bastion (NAT)
      - path: /etc/netplan/60-private-route.yaml
        permissions: "0600"
        content: |
          network:
            version: 2
            ethernets:
              ens10:
                dhcp4: no
                addresses: [${var.jumpserver_private_ip}/28]
                routes:
                  - to: 0.0.0.0/0
                    via: ${var.bastion_private_ip}
                nameservers:
                  addresses: [1.1.1.1, 8.8.8.8]

    runcmd:
      # Appliquer la configuration réseau
      - netplan apply

      # Mettre à jour les paquets (nécessaire pour résoudre les DNS)
      - apt-get update

      # Installer Docker et Docker Compose
      - apt-get install -y docker.io docker-compose ca-certificates curl wget
      - systemctl enable docker
      - systemctl start docker

      # Installer JumpServer
      - curl -sSL https://github.com/jumpserver/jumpserver/releases/latest/download/quick_start.sh | bash

  EOF
}

# ===================================================================
# OUTPUTS
# ===================================================================
output "bastion_public_ip" {
  description = "IP publique du serveur bastion (pour SSH et accès web)"
  value       = hcloud_server.bastion.ipv4_address
}

output "bastion_private_ip" {
  description = "IP privée du serveur bastion"
  value       = var.bastion_private_ip
}

output "jumpserver_private_ip" {
  description = "IP privée du serveur JumpServer (accessible via le bastion)"
  value       = var.jumpserver_private_ip
}

output "access_instructions" {
  description = "Instructions d'accès"
  value = <<-EOT
    
    ========================================
    SCENARIO 2 - Bastion + JumpServer Privé
    ========================================
    
    1. Accès SSH au bastion :
       ssh root@${hcloud_server.bastion.ipv4_address}
    
    2. Depuis le bastion, accès SSH au JumpServer privé :
       ssh root@${var.jumpserver_private_ip}
    
    3. Accès web JumpServer via Nginx reverse proxy :
       http://${hcloud_server.bastion.ipv4_address}
    
    Le bastion fait office de :
    - NAT server (permet au JumpServer privé de sortir sur Internet)
    - Reverse proxy Nginx (redirige le trafic HTTP vers JumpServer)
    - Bastion host (point d'entrée SSH)
    
  EOT
}
