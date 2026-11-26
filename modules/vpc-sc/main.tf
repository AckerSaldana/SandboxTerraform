resource "google_access_context_manager_access_policy" "this" {
  count  = var.access_policy == null ? 1 : 0
  parent = "organizations/${var.org_id}"
  title  = "politica-org"
}

locals {
  policy = var.access_policy == null ? google_access_context_manager_access_policy.this[0].name : var.access_policy

  # Paso 1 (enforced = false): la configuracion vive en spec y solo registra.
  # Paso 2 (enforced = true): la misma configuracion pasa a status y bloquea.
  config = {
    resources = [for n in var.project_numbers : "projects/${n}"]
    services  = var.restricted_services
    pipeline  = [for sa in var.ingress_service_accounts : "serviceAccount:${sa}"]
  }
}

resource "google_access_context_manager_service_perimeter" "this" {
  parent = "accessPolicies/${local.policy}"
  name   = "accessPolicies/${local.policy}/servicePerimeters/${var.perimeter_name}"
  title  = var.perimeter_name

  use_explicit_dry_run_spec = !var.enforced

  dynamic "spec" {
    for_each = var.enforced ? [] : [1]
    content {
      resources           = local.config.resources
      restricted_services = local.config.services

      vpc_accessible_services {
        enable_restriction = true
        allowed_services   = ["RESTRICTED-SERVICES"]
      }

      # El pipeline corre fuera del perimetro y necesita entrar para aplicar
      ingress_policies {
        ingress_from {
          identities = local.config.pipeline
          sources {
            access_level = "*"
          }
        }
        ingress_to {
          resources = ["*"]
          operations {
            service_name = "*"
          }
        }
      }
    }
  }

  dynamic "status" {
    for_each = var.enforced ? [1] : []
    content {
      resources           = local.config.resources
      restricted_services = local.config.services

      vpc_accessible_services {
        enable_restriction = true
        allowed_services   = ["RESTRICTED-SERVICES"]
      }

      ingress_policies {
        ingress_from {
          identities = local.config.pipeline
          sources {
            access_level = "*"
          }
        }
        ingress_to {
          resources = ["*"]
          operations {
            service_name = "*"
          }
        }
      }
    }
  }

  # Las etapas 4 y 5 agregan sus proyectos con recursos aparte.
  lifecycle {
    ignore_changes = [status[0].resources, spec[0].resources]
  }
}

# Evidencia continua de la metrica "0 copias fuera del perimetro"
resource "google_bigquery_dataset" "violations" {
  project    = var.logging_project
  dataset_id = "vpcsc_violaciones"
  location   = var.location
  labels     = var.labels

  dynamic "default_encryption_configuration" {
    for_each = var.kms_key == null ? [] : [1]
    content {
      kms_key_name = var.kms_key
    }
  }
}

resource "google_logging_organization_sink" "violations" {
  name             = "vpcsc-violaciones"
  org_id           = var.org_id
  include_children = true
  destination      = "bigquery.googleapis.com/projects/${var.logging_project}/datasets/${google_bigquery_dataset.violations.dataset_id}"
  filter           = "protoPayload.metadata.@type=\"type.googleapis.com/google.cloud.audit.VpcServiceControlAuditMetadata\""
}

resource "google_bigquery_dataset_iam_member" "sink_writer" {
  project    = var.logging_project
  dataset_id = google_bigquery_dataset.violations.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_organization_sink.violations.writer_identity
}
