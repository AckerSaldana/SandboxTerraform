# Cluster privado de GKE con node pools de GPU que escalan a cero.

resource "google_container_cluster" "this" {
  name                = var.name
  project             = var.project_id
  location            = var.region
  network             = var.network_id
  subnetwork          = var.subnet_id
  networking_mode     = "VPC_NATIVE"
  deletion_protection = var.deletion_protection
  resource_labels     = var.labels

  # El pool por defecto se elimina. Los pools reales se definen abajo.
  remove_default_node_pool = true
  initial_node_count       = 1

  node_config {
    service_account   = var.node_service_account
    boot_disk_kms_key = var.kms_key
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range
    services_secondary_range_name = var.services_range
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.admin_range
      display_name = "plataforma"
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Cadena de suministro: solo corren imagenes que cumplen la politica
  # de Binary Authorization del proyecto.
  binary_authorization {
    evaluation_mode = var.binary_authorization ? "PROJECT_SINGLETON_POLICY_ENFORCE" : "DISABLED"
  }

  database_encryption {
    state    = "ENCRYPTED"
    key_name = var.kms_key
  }

  release_channel {
    channel = "REGULAR"
  }

  # Reparte el costo del cluster por namespace y etiqueta en la facturacion
  cost_management_config {
    enabled = true
  }
}

resource "google_container_node_pool" "system" {
  name     = "sistema"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.this.name

  autoscaling {
    total_min_node_count = 1
    total_max_node_count = 3
  }

  node_config {
    machine_type          = "e2-standard-4"
    service_account       = var.node_service_account
    boot_disk_kms_key     = var.kms_key
    resource_labels       = var.labels
    resource_manager_tags = var.node_tags

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

resource "google_container_node_pool" "gpu" {
  for_each = var.gpu_node_pools
  name     = each.key
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.this.name

  # Cero nodos cuando no hay trabajos: ninguna GPU ociosa.
  autoscaling {
    total_min_node_count = 0
    total_max_node_count = each.value.max_nodes
    location_policy      = "ANY"
  }

  node_config {
    machine_type          = each.value.machine_type
    spot                  = each.value.spot
    flex_start            = each.value.flex_start ? true : null
    max_run_duration      = each.value.flex_start ? "604800s" : null
    service_account       = var.node_service_account
    boot_disk_kms_key     = var.kms_key
    resource_labels       = merge(var.labels, { gpu = each.key })
    resource_manager_tags = var.node_tags

    guest_accelerator {
      type  = each.value.gpu_type
      count = each.value.gpu_count

      gpu_driver_installation_config {
        gpu_driver_version = "DEFAULT"
      }

      # GPU compartida: varios notebooks o pruebas usan la misma GPU
      dynamic "gpu_sharing_config" {
        for_each = each.value.shared_clients > 1 ? [1] : []
        content {
          gpu_sharing_strategy       = "TIME_SHARING"
          max_shared_clients_per_gpu = each.value.shared_clients
        }
      }
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  lifecycle {
    ignore_changes = [node_config[0].taint]
  }
}
