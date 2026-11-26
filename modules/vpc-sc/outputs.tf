output "perimeter_name" {
  description = "Nombre completo del perimetro, para agregar proyectos desde otras etapas"
  value       = google_access_context_manager_service_perimeter.this.name
}

output "enforced" {
  description = "Indica si el perimetro esta en modo obligatorio"
  value       = var.enforced
}

output "violations_dataset" {
  description = "Dataset de BigQuery con las violaciones del perimetro"
  value       = google_bigquery_dataset.violations.dataset_id
}
