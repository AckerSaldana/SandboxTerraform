# Anonimizacion con Sensitive Data Protection. Un disparador diario
# inspecciona la zona raw, guarda los hallazgos en BigQuery y escribe la
# copia anonimizada en la zona curated.

locals {
  parent = "projects/${var.project_id}/locations/${var.region}"
}

resource "google_data_loss_prevention_inspect_template" "this" {
  parent       = local.parent
  template_id  = "aisbx-inspeccion"
  display_name = "Datos sensibles de la zona raw"

  inspect_config {
    min_likelihood = "POSSIBLE"

    dynamic "info_types" {
      for_each = toset(var.info_types)
      content {
        name = info_types.value
      }
    }
  }
}

resource "google_data_loss_prevention_deidentify_template" "this" {
  parent       = local.parent
  template_id  = "aisbx-anonimizacion"
  display_name = "Reemplaza cada dato sensible por su tipo"

  deidentify_config {
    info_type_transformations {
      transformations {
        primitive_transformation {
          replace_with_info_type_config = true
        }
      }
    }
  }
}

resource "google_bigquery_dataset" "findings" {
  project    = var.project_id
  dataset_id = "dlp_hallazgos"
  location   = var.region
  labels     = var.labels

  default_encryption_configuration {
    kms_key_name = var.bigquery_kms_key
  }
}

# El agente de servicio de DLP lee raw, escribe curated y guarda hallazgos
resource "google_storage_bucket_iam_member" "raw" {
  bucket = var.raw_bucket
  role   = "roles/storage.objectViewer"
  member = var.dlp_agent
}

resource "google_storage_bucket_iam_member" "curated" {
  bucket = var.curated_bucket
  role   = "roles/storage.objectAdmin"
  member = var.dlp_agent
}

resource "google_bigquery_dataset_iam_member" "findings" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.findings.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = var.dlp_agent
}

resource "google_data_loss_prevention_job_trigger" "raw_to_curated" {
  parent       = local.parent
  trigger_id   = "aisbx-raw-a-curated"
  display_name = "Anonimiza la zona raw hacia curated"

  triggers {
    schedule {
      recurrence_period_duration = "${var.period_hours * 3600}s"
    }
  }

  inspect_job {
    inspect_template_name = google_data_loss_prevention_inspect_template.this.id

    storage_config {
      cloud_storage_options {
        file_set {
          url = "gs://${var.raw_bucket}/**"
        }
      }

      # Cada corrida solo revisa lo nuevo
      timespan_config {
        enable_auto_population_of_timespan_config = true
      }
    }

    actions {
      save_findings {
        output_config {
          table {
            project_id = var.project_id
            dataset_id = google_bigquery_dataset.findings.dataset_id
            table_id   = "hallazgos"
          }
        }
      }
    }

    actions {
      deidentify {
        cloud_storage_output    = "gs://${var.curated_bucket}/"
        file_types_to_transform = ["TEXT_FILE", "CSV", "TSV"]

        transformation_config {
          deidentify_template = google_data_loss_prevention_deidentify_template.this.id
        }

        transformation_details_storage_config {
          table {
            project_id = var.project_id
            dataset_id = google_bigquery_dataset.findings.dataset_id
            table_id   = "transformaciones"
          }
        }
      }
    }
  }

  depends_on = [
    google_storage_bucket_iam_member.raw,
    google_storage_bucket_iam_member.curated,
    google_bigquery_dataset_iam_member.findings,
  ]
}
