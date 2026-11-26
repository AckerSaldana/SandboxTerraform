variable "tfstate_bucket" {
  description = "Bucket del estado de Terraform creado en 0-bootstrap"
  type        = string
}

variable "prefix" {
  description = "Prefijo de la empresa"
  type        = string
}

variable "region" {
  description = "Region principal"
  type        = string
  default     = "us-central1"
}

variable "alt_region" {
  description = "Region alterna"
  type        = string
  default     = "us-east4"
}

variable "platform_range" {
  description = "Rango completo de la plataforma"
  type        = string
  default     = "10.64.0.0/10"
}

variable "allowed_fqdns" {
  description = "Dominios aprobados para salir a Internet"
  type        = list(string)
  default = [
    "pypi.org",
    "files.pythonhosted.org",
    "huggingface.co",
    "cdn-lfs.huggingface.co",
    "github.com",
  ]
}

variable "flow_sampling" {
  description = "Muestreo de flow logs (0.1 = 10 %)"
  type        = number
  default     = 0.1
}

variable "enable_hybrid" {
  description = "Crea la HA VPN. Requiere que el secreto vpn-shared-secret ya tenga un valor"
  type        = bool
  default     = false
}

variable "onprem_gateway_ips" {
  description = "IP publicas del equipo VPN del cliente. Vacio = se simula on-premises con una segunda VPC"
  type        = list(string)
  default     = []
}

variable "onprem_cidr" {
  description = "Rango de la red de la empresa simulada. Confirmar con el cliente que no choque con su red"
  type        = string
  default     = "192.168.100.0/24"
}
