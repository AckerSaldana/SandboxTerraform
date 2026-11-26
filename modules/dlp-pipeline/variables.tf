variable "project_id" {
  description = "Proyecto ai-data"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
}

variable "raw_bucket" {
  description = "Bucket de la zona raw"
  type        = string
}

variable "curated_bucket" {
  description = "Bucket de la zona curated"
  type        = string
}

variable "dlp_agent" {
  description = "Agente de servicio de DLP, formato serviceAccount:service-NUMERO@dlp-api.iam.gserviceaccount.com"
  type        = string
}

variable "bigquery_kms_key" {
  description = "Llave CMEK de BigQuery"
  type        = string
}

variable "info_types" {
  description = "Tipos de dato sensible que se buscan"
  type        = list(string)
  default = [
    "PERSON_NAME",
    "EMAIL_ADDRESS",
    "PHONE_NUMBER",
    "CREDIT_CARD_NUMBER",
    "MEXICO_CURP_NUMBER",
    "MEXICO_PASSPORT",
    "STREET_ADDRESS",
    "DATE_OF_BIRTH",
  ]
}

variable "period_hours" {
  description = "Cada cuantas horas corre la anonimizacion"
  type        = number
  default     = 24
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
