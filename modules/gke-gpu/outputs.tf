output "cluster_name" {
  description = "Nombre del cluster"
  value       = google_container_cluster.this.name
}

output "cluster_id" {
  description = "Id del cluster"
  value       = google_container_cluster.this.id
}
