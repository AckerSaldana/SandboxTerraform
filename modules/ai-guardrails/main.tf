# Guardrails de IA responsable: plantilla de Model Armor y registro de
# prompts con retencion limitada.

resource "google_model_armor_template" "this" {
  project     = var.project_id
  location    = var.region
  template_id = "${var.prefix}-aisbx-base"
  labels      = var.labels

  filter_config {
    # Inyeccion de instrucciones y jailbreak
    pi_and_jailbreak_filter_settings {
      filter_enforcement = "ENABLED"
      confidence_level   = "MEDIUM_AND_ABOVE"
    }

    malicious_uri_filter_settings {
      filter_enforcement = "ENABLED"
    }

    # Fuga de datos sensibles en prompts y respuestas
    sdp_settings {
      basic_config {
        filter_enforcement = "ENABLED"
      }
    }

    rai_settings {
      dynamic "rai_filters" {
        for_each = toset(["HATE_SPEECH", "HARASSMENT", "SEXUALLY_EXPLICIT", "DANGEROUS"])
        content {
          filter_type      = rai_filters.value
          confidence_level = "MEDIUM_AND_ABOVE"
        }
      }
    }
  }

  template_metadata {
    log_template_operations = true
    log_sanitize_operations = true
  }
}

# Registro de prompts y respuestas. Las tablas vencen solas a los 90 dias.
resource "google_bigquery_dataset" "prompt_log" {
  project                         = var.project_id
  dataset_id                      = "registro_prompts"
  location                        = var.region
  labels                          = var.labels
  default_table_expiration_ms     = var.retention_days * 24 * 60 * 60 * 1000
  default_partition_expiration_ms = var.retention_days * 24 * 60 * 60 * 1000
  delete_contents_on_destroy      = var.force_destroy

  default_encryption_configuration {
    kms_key_name = var.bigquery_kms_key
  }
}
