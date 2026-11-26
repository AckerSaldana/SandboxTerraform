output "kms_keys" {
  description = "Mapa servicio => id de llave"
  value       = module.kms.key_ids
}

output "perimeter_name" {
  description = "Nombre completo del perimetro"
  value       = module.vpc_sc.perimeter_name
}

output "perimeter_enforced" {
  description = "Indica si el perimetro esta en modo obligatorio"
  value       = module.vpc_sc.enforced
}

output "vpn_secret" {
  description = "Nombre del secreto de la VPN"
  value       = google_secret_manager_secret.vpn.secret_id
}
