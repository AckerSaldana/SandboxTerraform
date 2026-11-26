output "network_id" {
  description = "Id de la red compartida"
  value       = google_compute_network.hub.id
}

output "network_name" {
  description = "Nombre de la red compartida"
  value       = google_compute_network.hub.name
}

output "subnet_ids" {
  description = "Mapa nombre => id de subred"
  value       = { for k, s in google_compute_subnetwork.base : k => s.id }
}

output "subnet_names" {
  description = "Mapa nombre => nombre completo de subred"
  value       = { for k, s in google_compute_subnetwork.base : k => s.name }
}

output "host_project" {
  description = "Proyecto anfitrion, disponible cuando la Shared VPC ya esta habilitada"
  value       = google_compute_shared_vpc_host_project.hub.project
}
