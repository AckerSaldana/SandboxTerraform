output "audit_bucket" {
  description = "Bucket de logs de auditoria"
  value       = google_logging_project_bucket_config.audit.id
}
