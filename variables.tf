variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 3
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
