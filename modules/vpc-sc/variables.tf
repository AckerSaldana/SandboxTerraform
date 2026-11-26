variable "org_id" {
  description = "Id de la organizacion"
  type        = string
}

variable "access_policy" {
  description = "Numero de una politica de acceso existente. Si es null, se crea"
  type        = string
  default     = null
}

variable "perimeter_name" {
  description = "Nombre del perimetro"
  type        = string
  default     = "aisbx"
}

variable "enforced" {
  description = "false = modo de prueba (solo registra). true = obligatorio (bloquea)"
  type        = bool
  default     = false
}

variable "project_numbers" {
  description = "Numeros de los proyectos iniciales dentro del perimetro"
  type        = list(string)
  default     = []
}

variable "restricted_services" {
  description = "Servicios protegidos por el perimetro"
  type        = list(string)
}

variable "ingress_service_accounts" {
  description = "Cuentas de servicio del pipeline que pueden entrar al perimetro"
  type        = list(string)
}

variable "logging_project" {
  description = "Proyecto donde se guardan las violaciones"
  type        = string
}

variable "location" {
  description = "Ubicacion del dataset de violaciones"
  type        = string
}

variable "kms_key" {
  description = "Llave CMEK para el dataset de violaciones"
  type        = string
  default     = null
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
