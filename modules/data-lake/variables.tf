variable "prefix" {
  description = "Prefijo de la empresa"
  type        = string
}

variable "project_id" {
  description = "Proyecto ai-data"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
}

variable "storage_kms_key" {
  description = "Llave CMEK de Cloud Storage"
  type        = string
}

variable "bigquery_kms_key" {
  description = "Llave CMEK de BigQuery"
  type        = string
}

variable "curated_readers" {
  description = "Lectores de la zona curated: etiqueta estatica => member"
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Permite borrar buckets y datasets con contenido (solo para pruebas)"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
