# Hetzner API Token (sensible)
variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

# Réseau privé existant
variable "private_network_name" {
  description = "Nom du réseau privé Hetzner existant"
  type        = string
  default     = "nw-chaima"
}

# Clé SSH existante
variable "ssh_key_name" {
  description = "Nom de la clé SSH dans Hetzner Cloud"
  type        = string
  default     = "chaima_pubkey"
}

# Type de serveur pour le bastion
variable "bastion_server_type" {
  description = "Type de serveur pour le bastion (NAT+Nginx)"
  type        = string
  default     = "cx23"
}

# Type de serveur pour le JumpServer privé
variable "jumpserver_server_type" {
  description = "Type de serveur pour le JumpServer privé"
  type        = string
  default     = "cx23"
}

# Localisation
variable "server_location" {
  description = "Emplacement des serveurs"
  type        = string
  default     = "hel1"
}

# Image système
variable "server_image" {
  description = "Image système"
  type        = string
  default     = "ubuntu-24.04"
}

# IP privée du bastion
variable "bastion_private_ip" {
  description = "IP privée du serveur bastion"
  type        = string
  default     = "10.40.0.20"
}

# IP privée du JumpServer
variable "jumpserver_private_ip" {
  description = "IP privée du serveur JumpServer"
  type        = string
  default     = "10.40.0.21"
}
