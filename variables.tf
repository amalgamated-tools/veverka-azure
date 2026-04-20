variable "vm_names" {
  description = "Names for the VMs"
  type        = list(string)
  default     = ["VAZURE1", "VAZURE2", "VAZURE3"]
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s_v2"
}

variable "location" {
  description = "Azure region (East US is cheapest)"
  type        = string
  default     = "East US"
}

variable "ssh_public_key" {
  description = "SSH public key content (from 1Password). MUST be RSA key (Azure does not support ed25519)"
  type        = string
  sensitive   = true
  
  validation {
    condition     = startswith(var.ssh_public_key, "ssh-rsa ")
    error_message = "SSH key must be RSA format (starts with 'ssh-rsa'). Azure does not support ed25519 keys."
  }
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key for automatic node registration"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_tunnel_token" {
  description = "Cloudflare Tunnel token for cloudflared"
  type        = string
  sensitive   = true
  default     = ""
}

variable "k3s_server_name" {
  description = "K3s server (control plane) VM name (typically VAZURE1)"
  type        = string
  default     = "VAZURE1"
}

variable "k3s_token" {
  description = "K3s cluster token (generated after first server starts)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "postgresql_password" {
  description = "PostgreSQL password for Honcho database"
  type        = string
  sensitive   = true
}

variable "honcho_enable" {
  description = "Enable Honcho deployment to K3s"
  type        = bool
  default     = false
}
