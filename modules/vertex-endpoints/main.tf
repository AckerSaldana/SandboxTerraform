# Endpoint privado de Vertex AI por Private Service Connect. Los modelos
# responden por IP interna, nunca por Internet.
resource "google_vertex_ai_endpoint" "this" {
  name         = var.endpoint_id
  display_name = var.display_name
  project      = var.project_id
  location     = var.region
  region       = var.region
  labels       = var.labels

  encryption_spec {
    kms_key_name = var.kms_key
  }

  private_service_connect_config {
    enable_private_service_connect = true
    project_allowlist              = var.project_allowlist
  }

  # Registro de prompts y respuestas para auditoria
  dynamic "predict_request_response_logging_config" {
    for_each = var.prompt_log_dataset == null ? [] : [1]
    content {
      enabled       = true
      sampling_rate = 1
      bigquery_destination {
        output_uri = "bq://${var.prompt_log_dataset}"
      }
    }
  }
}

# El adjunto de servicio existe hasta que se despliega un modelo en el
# endpoint. Cuando se conoce, esta regla lo conecta con la IP reservada
# en la etapa 3.
resource "google_compute_forwarding_rule" "psc" {
  count                 = var.service_attachment == null ? 0 : 1
  name                  = "${var.display_name}-psc"
  project               = var.network_project
  region                = var.region
  network               = var.network_id
  ip_address            = var.psc_address
  target                = var.service_attachment
  load_balancing_scheme = ""
}
