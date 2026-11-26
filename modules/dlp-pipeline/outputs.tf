output "findings_dataset" {
  description = "Dataset con los hallazgos de datos sensibles"
  value       = google_bigquery_dataset.findings.dataset_id
}

output "job_trigger" {
  description = "Disparador de anonimizacion"
  value       = google_data_loss_prevention_job_trigger.raw_to_curated.id
}
