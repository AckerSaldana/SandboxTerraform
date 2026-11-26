# Node pool de TPU sobre el cluster compartido. Solo se crea bajo solicitud.
resource "google_container_node_pool" "tpu" {
  name     = var.name
  project  = var.project_id
  location = var.region
  cluster  = var.cluster_name

  node_locations = var.zones

  autoscaling {
    total_min_node_count = 0
    total_max_node_count = var.max_nodes
    location_policy      = "ANY"
  }

  node_config {
    machine_type      = var.machine_type
    spot              = var.spot
    service_account   = var.node_service_account
    boot_disk_kms_key = var.kms_key
    resource_labels   = merge(var.labels, { acelerador = "tpu" })

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  # Las TPU de varios hosts necesitan colocacion compacta y topologia
  dynamic "placement_policy" {
    for_each = var.tpu_topology == null ? [] : [1]
    content {
      type         = "COMPACT"
      tpu_topology = var.tpu_topology
    }
  }
}
