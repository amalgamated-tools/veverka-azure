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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# Providers are passed from root module, no local configuration

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

# Deploy CloudNativePG operator
resource "helm_release" "cnpg_operator" {
  name             = "cnpg"
  repository       = "https://cloudnative-pg.io/charts"
  chart            = "cloudnative-pg"
  version          = "0.21.0"
  namespace        = kubernetes_namespace.honcho.metadata[0].name
  create_namespace = false

  set {
    name  = "monitoring.enabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.honcho]
}

# Wait for CloudNativePG CRD to be ready before creating the cluster
resource "time_sleep" "cnpg_crd_ready" {
  create_duration = "60s"
  depends_on      = [helm_release.cnpg_operator]
}

# Create PostgreSQL Cluster using CloudNativePG
resource "kubernetes_manifest" "postgresql_cluster" {
  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = "honcho-postgres"
      namespace = kubernetes_namespace.honcho.metadata[0].name
    }
    spec = {
      instances = var.postgresql_replica_count
      primaryUpdateStrategy = "unsupervised"
      postgresql = {
        parameters = {
          shared_buffers        = "256MB"
          effective_cache_size  = "1GB"
          maintenance_work_mem  = "64MB"
          checkpoint_completion_target = "0.9"
          wal_buffers           = "16MB"
        }
      }
      bootstrap = {
        initdb = {
          database = "honcho"
          owner    = "honcho"
          secret = {
            name = kubernetes_secret.postgresql_credentials.metadata[0].name
          }
        }
      }
      storage = {
        size             = var.postgresql_storage_size
        storageClassName = kubernetes_storage_class.fast.metadata[0].name
      }
      monitoring = {
        enabled = false
      }
    }
  }

  depends_on = [time_sleep.cnpg_crd_ready, kubernetes_secret.postgresql_credentials]
}

# Secret for PostgreSQL credentials
resource "kubernetes_secret" "postgresql_credentials" {
  metadata {
    name      = "postgresql-credentials"
    namespace = kubernetes_namespace.honcho.metadata[0].name
  }

  type = "kubernetes.io/basic-auth"

  data = {
    username = base64encode("honcho")
    password = base64encode(var.postgresql_password)
  }

  depends_on = [kubernetes_namespace.honcho]
}

# Deploy Valkey (Redis-compatible)
resource "helm_release" "valkey" {
  name             = "honcho-valkey"
  repository       = "https://valkey-io.github.io/valkey-helm-charts"
  chart            = "valkey"
  version          = "0.3.0"
  namespace        = kubernetes_namespace.honcho.metadata[0].name
  create_namespace = false

  values = [yamlencode({
    replicas = var.redis_replica_count
    persistence = {
      enabled      = true
      storageClass = kubernetes_storage_class.fast.metadata[0].name
      size         = var.redis_storage_size
    }
    resources = {
      requests = {
        memory = "256Mi"
        cpu    = "100m"
      }
      limits = {
        memory = "512Mi"
        cpu    = "500m"
      }
    }
  })]

  depends_on = [kubernetes_namespace.honcho]
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
