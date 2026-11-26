output "registry" {
  description = "Prefijo de los repositorios de Docker"
  value       = local.registry
}

output "images_repository" {
  description = "Id del repositorio de imagenes"
  value       = google_artifact_registry_repository.images.id
}

output "pypi_url" {
  description = "URL del espejo de PyPI para pip"
  value       = "https://${var.region}-python.pkg.dev/${var.project_id}/pypi-remoto/simple/"
}

output "pipelines_service_account" {
  description = "Cuenta de servicio de Vertex AI Pipelines"
  value       = google_service_account.pipelines.email
}

output "pipelines_bucket" {
  description = "Bucket de Vertex AI Pipelines"
  value       = google_storage_bucket.pipelines.name
}
