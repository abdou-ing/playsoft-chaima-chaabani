output "load_balancer_public_ipv4" {
  description = "Public IPv4 of Hetzner Load Balancer"
  value       = hcloud_load_balancer.jump.ipv4
}

output "load_balancer_private_ipv4" {
  description = "Private IPv4 of Load Balancer"
  value       = hcloud_load_balancer_network.jump.ip
}

output "jumpserver_private_ips" {
  description = "Private IPs of JumpServer nodes"
  value       = [for s in hcloud_server.jump : one(s.network).ip]
}

output "jumpserver_public_ips" {
  description = "Public IPv4s of JumpServer nodes"
  value       = hcloud_server.jump[*].ipv4_address
}

output "data_node_private_ip" {
  description = "Private IP of dedicated DB/Redis node"
  value       = one(hcloud_server.data.network).ip
}

output "data_node_public_ip" {
  description = "Public IPv4 of dedicated DB/Redis node"
  value       = hcloud_server.data.ipv4_address
}
