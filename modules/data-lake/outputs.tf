output "buckets" {
  description = "Mapa zona => nombre de bucket"
  value       = { for k, b in google_storage_bucket.zone : k => b.name }
}

output "datasets" {
  description = "Mapa zona => id de dataset"
  value       = { for k, d in google_bigquery_dataset.zone : k => d.dataset_id }
}
