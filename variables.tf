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
  description = "SSH public key content (from 1Password)"
  type        = string
  sensitive   = true
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
