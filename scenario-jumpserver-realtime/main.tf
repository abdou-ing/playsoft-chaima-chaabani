data "hcloud_ssh_key" "default" {
  name = var.ssh_key_name
}

data "hcloud_network" "private" {
  name = var.network_name
}

resource "hcloud_server" "data" {
  name        = "hzn-jump-realtime-data"
  image       = var.data_image
  server_type = var.data_server_type
  location    = var.location
  ssh_keys    = [data.hcloud_ssh_key.default.id]

  network {
    network_id = data.hcloud_network.private.id
    ip         = var.data_private_ip
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  user_data = templatefile("${path.module}/cloud-init-data.yml.tftpl", {
    db_name              = var.postgres_db
    db_user              = var.postgres_user
    db_password          = var.postgres_password
    redis_password       = var.redis_password
    allowed_net          = "10.40.0.0/24"
    storagebox_user        = var.storagebox_user
    storagebox_password    = var.storagebox_password
    storagebox_host        = var.storagebox_host
    storagebox_remote_path = var.storagebox_remote_path
  })

}

resource "hcloud_server" "jump" {
  count = var.jump_node_count

  name        = "hzn-jump-realtime-${count.index + 1}"
  image       = var.jump_image
  server_type = var.jump_server_type
  location    = var.location
  ssh_keys    = [data.hcloud_ssh_key.default.id]

  network {
    network_id = data.hcloud_network.private.id
    ip         = var.jump_private_ips[count.index]
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  user_data = templatefile("${path.module}/cloud-init-jumpserver.yml.tftpl", {
    node_name       = "jump-realtime-${count.index + 1}"
    db_host         = var.data_private_ip
    db_port         = 5432
    db_name         = var.postgres_db
    db_user         = var.postgres_user
    db_password     = var.postgres_password
    redis_host      = var.data_private_ip
    redis_port      = 6379
    redis_password  = var.redis_password
    storagebox_user        = var.storagebox_user
    storagebox_password    = var.storagebox_password
    storagebox_host        = var.storagebox_host
    storagebox_remote_path = var.storagebox_remote_path
  })

  depends_on = [hcloud_server.data]
}

resource "hcloud_load_balancer" "jump" {
  name               = "hzn-jump-realtime-lb"
  load_balancer_type = var.load_balancer_type
  location           = var.location

  algorithm {
    type = "round_robin"
  }
}

resource "hcloud_load_balancer_network" "jump" {
  load_balancer_id = hcloud_load_balancer.jump.id
  network_id       = data.hcloud_network.private.id
  ip               = var.lb_private_ip
}

resource "hcloud_load_balancer_target" "jump_nodes" {
  count = length(var.lb_target_node_indexes)

  type             = "server"
  load_balancer_id = hcloud_load_balancer.jump.id
  server_id        = hcloud_server.jump[var.lb_target_node_indexes[count.index]].id
  use_private_ip   = true

  depends_on = [hcloud_load_balancer_network.jump]
}

resource "hcloud_load_balancer_service" "http" {
  load_balancer_id = hcloud_load_balancer.jump.id
  protocol         = "http"
  listen_port      = 80
  destination_port = 80

  http {
    sticky_sessions = true
    cookie_name     = "JMS_LB_STICKY"
    cookie_lifetime = 3600
  }

  health_check {
    protocol = "http"
    port     = 80
    interval = 15
    timeout  = 10
    retries  = 3

    http {
      path         = "/"
      status_codes = ["200", "301", "302"]
      tls          = false
    }
  }

  depends_on = [hcloud_load_balancer_target.jump_nodes]
}
