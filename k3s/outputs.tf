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
