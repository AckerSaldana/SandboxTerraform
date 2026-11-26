variable "prefix" {
  description = "Prefijo de la empresa"
  type        = string
}

variable "project_id" {
  description = "Proyecto ai-platform"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
}

variable "kms_key" {
  description = "Llave CMEK para el bucket"
  type        = string
}

variable "force_destroy" {
  description = "Permite borrar el bucket con contenido (solo para pruebas)"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
