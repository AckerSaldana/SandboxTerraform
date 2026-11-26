# Lago de datos con dos zonas. La zona raw esta cerrada: solo entra el
# proceso de anonimizacion. La zona curated es la unica que ven los sandboxes.

locals {
  zones = toset(["raw", "curated"])
}

resource "google_storage_bucket" "zone" {
  for_each                    = local.zones
  name                        = "${var.prefix}-aisbx-${each.key}"
  project                     = var.project_id
  location                    = var.region
  labels                      = merge(var.labels, { zona = each.key })
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy

  # Versionado para cumplir el RPO de 24 horas
  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = var.storage_kms_key
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_bigquery_dataset" "zone" {
  for_each                   = local.zones
  project                    = var.project_id
  dataset_id                 = each.key
  location                   = var.region
  labels                     = merge(var.labels, { zona = each.key })
  delete_contents_on_destroy = var.force_destroy

  default_encryption_configuration {
    kms_key_name = var.bigquery_kms_key
  }
}

# Lectores de la zona curated (ademas de los sandboxes, que se agregan
# desde la fabrica)
resource "google_storage_bucket_iam_member" "curated_reader" {
  for_each = var.curated_readers
  bucket   = google_storage_bucket.zone["curated"].name
  role     = "roles/storage.objectViewer"
  member   = each.value
}

resource "google_bigquery_dataset_iam_member" "curated_reader" {
  for_each   = var.curated_readers
  project    = var.project_id
  dataset_id = google_bigquery_dataset.zone["curated"].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = each.value
}
