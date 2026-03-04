terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.87"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23"
    }
  }

  required_version = ">= 1.3.0"
}

# Yandex Cloud provider
# Prefer using a service account key file instead of token in real setups.
# See: https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs#example-usage
provider "yandex" {
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone

  # Either:
  # token                  = var.yc_token
  # or:
  service_account_key_file = var.yc_sa_key_file
}

# Kubernetes provider for deploying app manifests
data "yandex_client_config" "client" {}

provider "kubernetes" {
  host                   = yandex_kubernetes_cluster.vulnapp.master[0].external_v4_endpoint
  cluster_ca_certificate = yandex_kubernetes_cluster.vulnapp.master[0].cluster_ca_certificate
  token                  = data.yandex_client_config.client.iam_token
}

# VPC network
resource "yandex_vpc_network" "vulnapp" {
  name = "vulnapp-network"
}

# VPC subnet in one zone (for simplicity)
resource "yandex_vpc_subnet" "vulnapp" {
  name           = "vulnapp-subnet"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.vulnapp.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

# Service account for Kubernetes resources and nodes
resource "yandex_iam_service_account" "vulnapp" {
  name        = "vulnapp-k8s-sa"
  description = "Service account for vulnapp Kubernetes cluster"
}

# Grant roles to the service account (adjust as needed)
resource "yandex_resourcemanager_folder_iam_member" "editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.vulnapp.id}"
}

# Kubernetes cluster
resource "yandex_kubernetes_cluster" "vulnapp" {
  name        = "vulnapp"
  description = "Demo vulnerable Java app cluster"
  network_id  = yandex_vpc_network.vulnapp.id

  master {
    version = "1.30" # adjust as needed

    zonal {
      zone      = yandex_vpc_subnet.vulnapp.zone
      subnet_id = yandex_vpc_subnet.vulnapp.id
    }

    public_ip = true

    maintenance_policy {
      auto_upgrade = true
      maintenance_window {
        start_time = "03:00"
        duration   = "3h"
      }
    }
  }

  service_account_id      = yandex_iam_service_account.vulnapp.id
  node_service_account_id = yandex_iam_service_account.vulnapp.id

  release_channel         = "STABLE"
  network_policy_provider = "CALICO"

  # Optional: enable KMS encryption for secrets (recommended for production)
  # kms_provider {
  #   key_id = yandex_kms_symmetric_key.k8s.id
  # }
}

# Node group for the cluster
resource "yandex_kubernetes_node_group" "vulnapp" {
  cluster_id  = yandex_kubernetes_cluster.vulnapp.id
  name        = "vulnapp-ng"
  description = "Node group for vulnapp demo"
  version     = "1.30"

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.vulnapp.id]
    }

    resources {
      memory = 4
      cores  = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    location {
      zone = yandex_vpc_subnet.vulnapp.zone
    }
  }

  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true
  }
}