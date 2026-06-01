variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "network_name" {
  description = "Existing Hetzner private network name"
  type        = string
  default     = "nw-chaima"
}

variable "ssh_key_name" {
  description = "Existing SSH key name in Hetzner Cloud"
  type        = string
  default     = "chaima_pubkey"
}

variable "location" {
  description = "Hetzner location"
  type        = string
  default     = "hel1"
}

variable "jump_image" {
  description = "JumpServer nodes image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "jump_server_type" {
  description = "JumpServer node type"
  type        = string
  default     = "cx23"
}

variable "data_image" {
  description = "DB/Redis node image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "data_server_type" {
  description = "DB/Redis node type (low cost)"
  type        = string
  default     = "cx23"
}

variable "jump_node_count" {
  description = "Number of JumpServer nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.jump_node_count == 2
    error_message = "This scenario expects exactly 2 JumpServer nodes."
  }
}

variable "lb_target_node_indexes" {
  description = "Node indexes attached to LB. Keep [0,1] for active/active app nodes."
  type        = list(number)
  default     = [0, 1]

  validation {
    condition     = length(var.lb_target_node_indexes) >= 1
    error_message = "lb_target_node_indexes must contain at least one node index."
  }

  validation {
    condition     = alltrue([for i in var.lb_target_node_indexes : i >= 0 && i < var.jump_node_count])
    error_message = "Each lb_target_node_indexes value must be a valid node index."
  }
}

variable "load_balancer_type" {
  description = "Hetzner load balancer type"
  type        = string
  default     = "lb11"
}

variable "jump_private_ips" {
  description = "Private IPs for JumpServer nodes"
  type        = list(string)
  default     = ["10.40.0.31", "10.40.0.32"]

  validation {
    condition     = length(var.jump_private_ips) >= var.jump_node_count
    error_message = "jump_private_ips must contain at least jump_node_count IPs."
  }
}

variable "lb_private_ip" {
  description = "Private IP of load balancer"
  type        = string
  default     = "10.40.0.30"
}

variable "data_private_ip" {
  description = "Private IP of dedicated DB/Redis node"
  type        = string
  default     = "10.40.0.40"
}

variable "postgres_db" {
  description = "JumpServer PostgreSQL DB name"
  type        = string
  default     = "jumpserver"
}

variable "postgres_user" {
  description = "JumpServer PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "postgres_password" {
  description = "JumpServer PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

variable "storagebox_user" {
  description = "Nom d'utilisateur Storage Box"
  type        = string
}

variable "storagebox_password" {
  description = "Mot de passe Storage Box"
  type        = string
  sensitive   = true
}

variable "storagebox_host" {
  description = "Hôte Storage Box"
  type        = string
}

variable "storagebox_remote_path" {
  description = "Chemin distant Storage Box (ex: /backup/)"
  type        = string
}
