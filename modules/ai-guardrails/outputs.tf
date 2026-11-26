output "model_armor_template" {
  description = "Plantilla de Model Armor"
  value       = google_model_armor_template.this.id
}

output "prompt_log_dataset" {
  description = "Dataset del registro de prompts, formato proyecto.dataset"
  value       = "${var.project_id}.${google_bigquery_dataset.prompt_log.dataset_id}"
}
