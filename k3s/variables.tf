variable "k3s_server_ip" {
  description = "K3s server (control plane) IP address or hostname"
  type        = string
}

variable "k3s_token" {
  description = "K3s cluster token for agent authentication"
  type        = string
  sensitive   = true
}

variable "k3s_ca_cert" {
  description = "K3s cluster CA certificate"
  type        = string
  sensitive   = true
  default     = ""
}

variable "insecure_skip_tls_verify" {
  description = "Skip TLS verification (for testing only!)"
  type        = bool
  default     = true # TODO: Set to false and provide CA cert
}

variable "cluster_name" {
  description = "K3s cluster name"
  type        = string
  default     = "veverka-k3s"
}

variable "azure_region" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "k3s_node_count" {
  description = "Number of K3s nodes"
  type        = number
  default     = 3
}

variable "honcho_namespace" {
  description = "Kubernetes namespace for Honcho stack"
  type        = string
  default     = "honcho"
}

variable "workflows_namespace" {
  description = "Kubernetes namespace for workflows (n8n, etc.)"
  type        = string
  default     = "workflows"
}

variable "postgresql_storage_size" {
  description = "PostgreSQL persistent volume size"
  type        = string
  default     = "10Gi"
}

variable "redis_storage_size" {
  description = "Redis persistent volume size"
  type        = string
  default     = "5Gi"
}

variable "postgresql_password" {
  description = "PostgreSQL password for Honcho"
  type        = string
  sensitive   = true
}

variable "honcho_replica_count" {
  description = "Number of Honcho API replicas"
  type        = number
  default     = 1
}

variable "redis_replica_count" {
  description = "Number of Redis replicas"
  type        = number
  default     = 1
}

variable "n8n_storage_size" {
  description = "n8n persistent volume size"
  type        = string
  default     = "20Gi"
}

variable "qdrant_storage_size" {
  description = "Qdrant persistent volume size"
  type        = string
  default     = "50Gi"
}
