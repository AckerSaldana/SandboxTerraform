# Base para agentes: identidad propia y, si se indica una imagen, un
# servicio de Cloud Run interno que escala a cero.
resource "google_service_account" "agents" {
  project      = var.project_id
  account_id   = "sa-agentes"
  display_name = "Agentes de IA"
}

resource "google_project_iam_member" "agents" {
  for_each = toset(["roles/aiplatform.user", "roles/logging.logWriter"])
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.agents.email}"
}

resource "google_cloud_run_v2_service" "agent" {
  count               = var.image == null ? 0 : 1
  name                = var.name
  project             = var.project_id
  location            = var.region
  labels              = var.labels
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false

  template {
    service_account = google_service_account.agents.email
    encryption_key  = var.kms_key

    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image
    }

    vpc_access {
      egress = "ALL_TRAFFIC"
      network_interfaces {
        network    = var.network_id
        subnetwork = var.subnet_id
      }
    }
  }
}
