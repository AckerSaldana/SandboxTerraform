# Base para ajuste fino en Vertex AI Training: cuenta de servicio y bucket
# de trabajo. Los trabajos se lanzan con la API o con Vertex AI Pipelines
# y se registran en Model Registry.
resource "google_service_account" "training" {
  project      = var.project_id
  account_id   = "sa-training"
  display_name = "Trabajos de ajuste fino"
}

resource "google_project_iam_member" "training" {
  for_each = toset(["roles/aiplatform.user", "roles/artifactregistry.reader", "roles/logging.logWriter"])
  project  = var.project_id
  role     = each.key
  member   = "serviceAccount:${google_service_account.training.email}"
}

resource "google_storage_bucket" "staging" {
  name                        = "${var.prefix}-aisbx-training"
  project                     = var.project_id
  location                    = var.region
  labels                      = var.labels
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy

  encryption {
    default_kms_key_name = var.kms_key
  }

  # Los artefactos intermedios se borran solos
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "training" {
  bucket = google_storage_bucket.staging.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.training.email}"
}
