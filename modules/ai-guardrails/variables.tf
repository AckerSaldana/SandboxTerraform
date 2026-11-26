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

variable "bigquery_kms_key" {
  description = "Llave CMEK de BigQuery"
  type        = string
}

variable "retention_days" {
  description = "Dias que se conserva el registro de prompts"
  type        = number
  default     = 90
}

variable "force_destroy" {
  description = "Permite borrar el dataset con contenido (solo para pruebas)"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
