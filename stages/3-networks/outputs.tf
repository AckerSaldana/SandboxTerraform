output "host_project" {
  description = "Proyecto anfitrion de la Shared VPC"
  value       = module.hub.host_project
}

output "network_id" {
  description = "Id de la red compartida"
  value       = module.hub.network_id
}

output "network_name" {
  description = "Nombre de la red compartida"
  value       = module.hub.network_name
}

output "subnet_ids" {
  description = "Mapa nombre => id de subred"
  value       = module.hub.subnet_ids
}

output "subnet_names" {
  description = "Mapa nombre => nombre de subred"
  value       = module.hub.subnet_names
}

output "sandbox_range" {
  description = "Rango del que cada sandbox toma su /16"
  value       = cidrsubnet(var.platform_range, 1, 1)
}

output "egress_tag" {
  description = "Secure tag que permite salir a los dominios aprobados"
  value = {
    key   = module.firewall.egress_tag_key
    value = module.firewall.egress_tag_value
  }
}

output "vertex_psc_address" {
  description = "Direccion interna reservada para el endpoint privado de Vertex AI"
  value       = google_compute_address.vertex_psc.self_link
}
