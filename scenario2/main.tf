
# DATA
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
  ip_range     = "10.40.0.16/28"
}

# FIREWALLS
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

  rule {
    direction       = "out"
    protocol        = "udp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall" "jump_fw" {
  name = "fw-jump"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["10.40.0.0/24"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["10.40.0.0/24"]
  }
}

########################
# BASTION PUBLIC
########################
resource "hcloud_server" "bastion" {
  name        = "hzn-bastion-chaima"
  image       = var.image
  server_type = var.bastion_type
  location    = var.location
  ssh_keys    = [data.hcloud_ssh_key.key.id]
  firewall_ids = [hcloud_firewall.bastion_fw.id]

  network {
    network_id = data.hcloud_network.net.id
    ip         = var.bastion_ip
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

 user_data = <<EOF
#cloud-config

package_update: true
package_upgrade: true

packages:
  - iptables-persistent
  - nginx

write_files:
  - path: /usr/local/bin/nat.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      echo 1 > /proc/sys/net/ipv4/ip_forward

      iptables -t nat -C POSTROUTING -s 10.40.0.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -s 10.40.0.0/24 -o eth0 -j MASQUERADE

      netfilter-persistent save

  - path: /etc/nginx/sites-available/jumpserver
    content: |
      server {
        listen 80;
        location / {
          proxy_pass http://10.40.0.21:80;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
      }

runcmd:
  - echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  - sysctl -p
  - /usr/local/bin/nat.sh
  - ln -sf /etc/nginx/sites-available/jumpserver /etc/nginx/sites-enabled/jumpserver
  - rm -f /etc/nginx/sites-enabled/default
  - nginx -t
  - systemctl restart nginx
  - reboot
EOF
}

########################
# JUMPSERVER PRIVATE
########################
resource "hcloud_server" "jumpserver" {
  name        = "hzn-jumpserver-chaima"
  image       = var.image
  server_type = var.jump_type
  location    = var.location
  ssh_keys    = [data.hcloud_ssh_key.key.id]
  firewall_ids = [hcloud_firewall.jump_fw.id]

  network {
    network_id = data.hcloud_network.net.id
    ip         = var.jump_ip
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

 user_data = <<EOF
#cloud-config
package_update: true
package_upgrade: true

packages:
  - docker.io
  - curl
  - git
  - python3-pip
  - libffi-dev
  - libssl-dev
  

write_files:
  - path: /etc/systemd/network/10-enp7s0.network
    content: |
      [Match]
      Name=enp7s0

      [Network]
      DHCP=yes
      Gateway=10.40.0.1

  - path: /etc/systemd/resolved.conf
    content: |
      [Resolve]
      DNS=185.12.64.2 185.12.64.1
      FallbackDNS=8.8.8.8

runcmd:
  # Redémarrer le réseau pour appliquer la gateway
  - systemctl restart systemd-networkd
  - systemctl restart systemd-resolved
  - sleep 5

  # Docker
  - systemctl enable docker
  - systemctl start docker
  - sleep 10

  # Installation JumpServer (mode rapide officiel)
  - curl -sSL https://github.com/jumpserver/jumpserver/releases/latest/download/quick_start.sh -o /tmp/jumpserver.sh
  - chmod +x /tmp/jumpserver.sh
  - bash /tmp/jumpserver.sh > /var/log/jumpserver-install.log 2>&1

  # Nettoyage
  - apt remove -y hc-utils || true

  - reboot
EOF
}