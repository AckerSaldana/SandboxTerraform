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

variable "sandbox_folder" {
  description = "Carpeta ai-sandbox (folders/NUMERO)"
  type        = string
}

variable "source_dir" {
  description = "Carpeta con el codigo de la funcion"
  type        = string
}

variable "artifacts_kms_key" {
  description = "Llave CMEK de la funcion"
  type        = string
}

variable "storage_kms_key" {
  description = "Llave CMEK del bucket con el codigo"
  type        = string
}

variable "pubsub_kms_key" {
  description = "Llave CMEK del tema de Pub/Sub"
  type        = string
  default     = null
}

variable "budget_publisher" {
  description = "Cuenta con la que Cloud Billing publica las notificaciones de presupuesto"
  type        = string
  default     = "serviceAccount:billing-budget-alert@system.gserviceaccount.com"
}

variable "stop_at_threshold" {
  description = "Fraccion del presupuesto a la que se detienen los recursos (1.0 = 100 %)"
  type        = number
  default     = 1.0
}

variable "dry_run" {
  description = "true = la funcion solo registra lo que detendria"
  type        = bool
  default     = false
}

variable "billing_export_table" {
  description = "Tabla de la exportacion detallada de facturacion, formato proyecto.dataset.tabla. null = no crear vistas"
  type        = string
  default     = null
}

variable "views_project" {
  description = "Proyecto donde se crean las vistas de costo"
  type        = string
  default     = null
}

variable "views_location" {
  description = "Ubicacion del dataset de vistas. Debe coincidir con la del dataset de la exportacion"
  type        = string
  default     = "us-central1"
}

variable "views_kms_key" {
  description = "Llave CMEK del dataset de vistas"
  type        = string
  default     = null
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
