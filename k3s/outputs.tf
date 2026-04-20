output "k3s_cluster_name" {
  description = "K3s cluster name"
  value       = var.cluster_name
}

output "k3s_server_url" {
  description = "K3s server URL"
  value       = "https://${var.k3s_server_ip}:6443"
}

output "honcho_namespace" {
  description = "Honcho namespace"
  value       = kubernetes_namespace.honcho.metadata[0].name
}

output "workflows_namespace" {
  description = "Workflows namespace"
  value       = kubernetes_namespace.workflows.metadata[0].name
}

output "kubeconfig_path" {
  description = "Path to kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "storage_class_name" {
  description = "Storage class for persistent volumes"
  value       = kubernetes_storage_class.fast.metadata[0].name
}

output "postgresql_connection_string" {
  description = "CloudNativePG connection string for Honcho"
  value       = "postgresql://honcho:${var.postgresql_password}@honcho-postgres-rw.${kubernetes_namespace.honcho.metadata[0].name}.svc.cluster.local:5432/honcho"
  sensitive   = true
}

output "postgresql_host" {
  description = "PostgreSQL service hostname"
  value       = "honcho-postgres-rw.${kubernetes_namespace.honcho.metadata[0].name}.svc.cluster.local"
}

output "postgresql_port" {
  description = "PostgreSQL port"
  value       = 5432
}

output "valkey_connection_string" {
  description = "Valkey (Redis) connection string for Honcho"
  value       = "redis://honcho-valkey-master.${kubernetes_namespace.honcho.metadata[0].name}.svc.cluster.local:6379"
}

output "valkey_host" {
  description = "Valkey service hostname"
  value       = "honcho-valkey-master.${kubernetes_namespace.honcho.metadata[0].name}.svc.cluster.local"
}

output "valkey_port" {
  description = "Valkey port"
  value       = 6379
}
