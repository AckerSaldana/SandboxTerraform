variable "prefix" {
  description = "Prefijo de la empresa"
  type        = string
}

variable "project_id" {
  description = "Proyecto net-hub"
  type        = string
}

variable "network_id" {
  description = "Id de la red compartida"
  type        = string
}

variable "region" {
  description = "Region de la VPN"
  type        = string
}

variable "asn" {
  description = "ASN del lado de la plataforma"
  type        = number
  default     = 64514
}

variable "peer_asn" {
  description = "ASN del lado de la empresa"
  type        = number
  default     = 64515
}

variable "shared_secret" {
  description = "Secreto compartido de la VPN. Se lee de Secret Manager, nunca del codigo"
  type        = string
  sensitive   = true
}

variable "external_gateway_ips" {
  description = "IP publicas del equipo VPN del sitio fisico. Si se indica, no se simula on-premises"
  type        = list(string)
  default     = []
}

variable "peer_gcp_gateway" {
  description = "Gateway de HA VPN de otra VPC de Google Cloud. Si es null y no hay sitio fisico, se simula on-premises"
  type        = string
  default     = null
}

variable "onprem_cidr" {
  description = "Rango de la red de la empresa simulada"
  type        = string
  default     = "192.168.100.0/24"
}
