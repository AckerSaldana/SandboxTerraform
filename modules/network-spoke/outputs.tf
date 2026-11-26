output "subnet_id" {
  description = "Id de la subred del sandbox"
  value       = google_compute_subnetwork.this.id
}

output "subnet_name" {
  description = "Nombre de la subred del sandbox"
  value       = google_compute_subnetwork.this.name
}
