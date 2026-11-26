variable "org_id" {
  description = "Id de la organizacion"
  type        = string
}

variable "project_id" {
  description = "Proyecto logging"
  type        = string
}

variable "location" {
  description = "Ubicacion del bucket de logs"
  type        = string
}

variable "retention_days" {
  description = "Dias de retencion de los logs de auditoria"
  type        = number
  default     = 365
}

variable "data_access_folder" {
  description = "Carpeta donde se activan los logs de acceso a datos (null = no activar)"
  type        = string
  default     = null
}

variable "data_access_services" {
  description = "Servicios con logs de acceso a datos"
  type        = list(string)
  default = [
    "storage.googleapis.com",
    "bigquery.googleapis.com",
    "aiplatform.googleapis.com",
  ]
}
