# Hetzner API Token (sensible)
variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

# Nom du serveur JumpServer
variable "server_name" {
  description = "Nom du serveur JumpServer"
  type        = string
  default     = "public-jumpserver-chaima"
}

# Type de serveur Hetzner
variable "server_type" {
  description = "Type de serveur Hetzner (cx23, cx33, etc.)"
  type        = string
  default     = "cx23"
}

# Localisation du serveur
variable "server_location" {
  description = "Emplacement du serveur Hetzner"
  type        = string
  default     = "hel1"
}

# Image du serveur
variable "server_image" {
  description = "Image du serveur (Ubuntu, Debian, etc.)"
  type        = string
  default     = "ubuntu-24.04"
}

# Clé SSH déjà ajoutée dans Hetzner
variable "ssh_key_name" {
  description = "Nom de la clé SSH déjà ajoutée dans Hetzner Cloud"
  type        = string
  default     = "chaima_key"
}

# Réseau privé existant
variable "private_network_name" {
  description = "Nom du réseau privé Hetzner existant"
  type        = string
  default     = "nw-chaima"
}

# IP privée du serveur dans le réseau privé
variable "private_ip" {
  description = "IP privée du serveur dans le réseau privé"
  type        = string
  default     = "10.40.0.3"
}
