output "egress_tag_key" {
  description = "Clave de la secure tag de salida (tagKeys/...)"
  value       = google_tags_tag_key.egress.id
}

output "egress_tag_value" {
  description = "Valor de la secure tag que permite salir a los dominios aprobados (tagValues/...)"
  value       = google_tags_tag_value.repos.id
}
