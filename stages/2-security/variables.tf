variable "org_id" {
  description = "Id numerico de la organizacion"
  type        = string
}

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

variable "access_policy" {
  description = "Numero de una politica de acceso existente. Una organizacion solo admite una. Si es null, se crea"
  type        = string
  default     = null
}

variable "perimeter_enforced" {
  description = "false = modo de prueba (solo registra). true = obligatorio. Cambiar a true cuando el registro ya no muestre accesos legitimos"
  type        = bool
  default     = false
}

variable "restricted_services" {
  description = "Servicios protegidos por el perimetro"
  type        = list(string)
  default = [
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "aiplatform.googleapis.com",
    "notebooks.googleapis.com",
    "artifactregistry.googleapis.com",
    "dlp.googleapis.com",
    "pubsub.googleapis.com",
  ]
}

variable "cmek_services" {
  description = "Servicios que solo aceptan recursos cifrados con llave propia"
  type        = list(string)
  default = [
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "aiplatform.googleapis.com",
    "notebooks.googleapis.com",
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
  ]
}
