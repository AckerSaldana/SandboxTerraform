output "seed_project_id" {
  description = "Proyecto semilla"
  value       = google_project.seed.project_id
}

output "tfstate_bucket" {
  description = "Bucket del estado. Valor de la variable TFSTATE_BUCKET en GitHub"
  value       = google_storage_bucket.tfstate.name
}

output "wif_provider" {
  description = "Valor de la variable WIF_PROVIDER en GitHub"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "stage_service_accounts" {
  description = "Valores de las variables TF_SA_<ETAPA> en GitHub"
  value       = { for k, sa in google_service_account.stage : k => sa.email }
}
