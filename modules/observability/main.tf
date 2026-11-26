# Auditoria centralizada en un proyecto aparte: un equipo no puede borrar
# los logs de su propio sandbox.
resource "google_logging_project_bucket_config" "audit" {
  project        = var.project_id
  location       = var.location
  bucket_id      = "auditoria"
  retention_days = var.retention_days
}

resource "google_logging_organization_sink" "audit" {
  name             = "auditoria-central"
  org_id           = var.org_id
  include_children = true
  destination      = "logging.googleapis.com/${google_logging_project_bucket_config.audit.id}"
  filter           = "logName:\"cloudaudit.googleapis.com\""
}

resource "google_project_iam_member" "sink_writer" {
  project = var.project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_organization_sink.audit.writer_identity
}

# Logs de acceso a datos solo en los servicios que guardan datos o modelos.
resource "google_folder_iam_audit_config" "data_access" {
  for_each = var.data_access_folder == null ? toset([]) : toset(var.data_access_services)
  folder   = var.data_access_folder
  service  = each.key

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
