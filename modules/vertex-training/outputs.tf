output "service_account" {
  description = "Cuenta de servicio de los trabajos de ajuste fino"
  value       = google_service_account.training.email
}

output "staging_bucket" {
  description = "Bucket de trabajo"
  value       = google_storage_bucket.staging.name
}
