# main.tf
provider "contabo" {
  oauth2_client_id     = var.contabo_client_id
  oauth2_client_secret = var.contabo_client_secret
  oauth2_user          = var.contabo_username
  oauth2_pass          = var.contabo_password
}

resource "contabo_instance" "osint_server" {
  display_name = "osint-command-center"
  product_id   = "V1"  # Cloud VPS 20 SSD - 6 CPU, 12GB RAM, 200GB SSD
  region       = "EU"  # Choose appropriate region
  
  image_id     = "ubuntu-22.04"
  
  # Configure SSH key (generated on your PC)
  ssh_keys     = [contabo_ssh_key.main_key.id]
}

resource "contabo_ssh_key" "main_key" {
  name       = "osint-access-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

output "server_ip" {
  value = contabo_instance.osint_server.ip_address
}

# Variables
variable "contabo_client_id" {
  description = "Contabo API Client ID"
  type        = string
  sensitive   = true
}

variable "contabo_client_secret" {
  description = "Contabo API Client Secret"
  type        = string
  sensitive   = true
}

variable "contabo_username" {
  description = "Contabo API Username"
  type        = string
  sensitive   = true
}

variable "contabo_password" {
  description = "Contabo API Password"
  type        = string
  sensitive   = true
}