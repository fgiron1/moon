# main.tf
provider "contabo" {
  oauth2_client_id     = var.contabo_client_id
  oauth2_client_secret = var.contabo_client_secret
  oauth2_user          = var.contabo_username
  oauth2_pass          = var.contabo_password
}

resource "contabo_instance" "osint_server" {
  display_name = "osint-command-center"
  product_id   = "V1"  # Adjust based on your chosen VPS size
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