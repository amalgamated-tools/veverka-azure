# K3s Kubernetes Cluster on Azure
# 3-node cluster: VAZURE1 (control plane), VAZURE2 & VAZURE3 (workers)

# This module expects the VMs to already exist and have K3s installed via user_data.sh
# It configures K3s networking, storage, and deploys core services

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Configure Kubernetes provider to connect to K3s cluster
provider "kubernetes" {
  host                   = "https://${var.k3s_server_ip}:6443"
  token                  = var.k3s_token
  insecure               = var.insecure_skip_tls_verify
  skip_credentials_validation = var.skip_credentials_validation
}

provider "helm" {
  kubernetes {
    host                   = "https://${var.k3s_server_ip}:6443"
    token                  = var.k3s_token
    insecure               = var.insecure_skip_tls_verify
    skip_credentials_validation = var.skip_credentials_validation
  }
}

# Create namespace for Honcho stack
resource "kubernetes_namespace" "honcho" {
  metadata {
    name = var.honcho_namespace
  }
}

# Create namespace for n8n
resource "kubernetes_namespace" "workflows" {
  metadata {
    name = var.workflows_namespace
  }
}

# ConfigMap for K3s cluster info
resource "kubernetes_config_map" "cluster_info" {
  metadata {
    name      = "cluster-info"
    namespace = "default"
  }

  data = {
    cluster_name = var.cluster_name
    region       = var.azure_region
    nodes        = var.k3s_node_count
  }
}

# StorageClass for Honcho data
resource "kubernetes_storage_class" "fast" {
  metadata {
    name = "fast"
  }
  storage_provisioner = "rancher.io/local-path"
  reclaim_policy      = "Retain"
  allow_volume_expansion = true
}

# PersistentVolumeClaim for PostgreSQL
resource "kubernetes_persistent_volume_claim" "postgresql" {
  metadata {
    name      = "postgresql-pvc"
    namespace = kubernetes_namespace.honcho.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.fast.metadata[0].name
    resources {
      requests = {
        storage = var.postgresql_storage_size
      }
    }
  }
}

# PersistentVolumeClaim for Redis
resource "kubernetes_persistent_volume_claim" "redis" {
  metadata {
    name      = "redis-pvc"
    namespace = kubernetes_namespace.honcho.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.fast.metadata[0].name
    resources {
      requests = {
        storage = var.redis_storage_size
      }
    }
  }
}

# ConfigMap for PostgreSQL initialization
resource "kubernetes_config_map" "postgresql_init" {
  metadata {
    name      = "postgresql-init-script"
    namespace = kubernetes_namespace.honcho.metadata[0].name
  }

  data = {
    "init.sql" = <<-EOT
      CREATE DATABASE honcho;
      CREATE USER honcho_user WITH PASSWORD '${var.postgresql_password}';
      GRANT ALL PRIVILEGES ON DATABASE honcho TO honcho_user;
    EOT
  }
}

# Output kubeconfig for manual kubectl access
resource "local_file" "kubeconfig" {
  content = templatefile("${path.module}/kubeconfig.tpl", {
    server   = "https://${var.k3s_server_ip}:6443"
    token    = var.k3s_token
    ca_cert  = var.k3s_ca_cert
    cluster_name = var.cluster_name
  })
  filename = "${path.module}/kubeconfig.yaml"
}
