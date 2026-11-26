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

variable "network_name" {
  description = "Nombre de la red compartida"
  type        = string
}

variable "folder_id" {
  description = "Carpeta ai-sandbox, donde se asocia la politica jerarquica"
  type        = string
}

variable "allowed_fqdns" {
  description = "Dominios aprobados para salir a Internet por el puerto 443"
  type        = list(string)
}

variable "internal_ranges" {
  description = "Rangos internos de la plataforma"
  type        = list(string)
  default     = ["10.64.0.0/10"]
}

variable "health_check_ranges" {
  description = "Rangos de los health checks de Google, necesarios para balanceadores y GKE"
  type        = list(string)
  default     = ["35.191.0.0/16", "130.211.0.0/22"]
}

variable "iap_range" {
  description = "Rango de origen de Identity-Aware Proxy"
  type        = string
  default     = "35.235.240.0/20"
}
