output "project_id" {
  description = "Id del proyecto, disponible cuando sus APIs ya estan habilitadas"
  value       = google_project.this.project_id

  depends_on = [google_project_service.this]
}

output "number" {
  description = "Numero del proyecto"
  value       = google_project.this.number
}
