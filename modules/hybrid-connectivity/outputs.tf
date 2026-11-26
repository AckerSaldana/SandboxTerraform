output "gateway_id" {
  description = "Gateway de HA VPN de la plataforma"
  value       = google_compute_ha_vpn_gateway.hub.id
}

output "onprem_network_id" {
  description = "Red que simula on-premises (null si la conexion es real)"
  value       = local.simulate ? google_compute_network.onprem[0].id : null
}

output "onprem_test_ip" {
  description = "IP de la red simulada para las pruebas de conectividad"
  value       = local.simulate ? cidrhost(var.onprem_cidr, 10) : null
}
