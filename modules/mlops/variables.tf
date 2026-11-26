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
  description = "Llave CMEK de Artifact Registry"
  type        = string
}

variable "storage_kms_key" {
  description = "Llave CMEK de Cloud Storage"
  type        = string
}

variable "readers" {
  description = "Quien puede descargar de los repositorios: etiqueta estatica => member"
  type        = map(string)
  default     = {}
}

variable "binauthz_enforced" {
  description = "false = modo de prueba (deja pasar y registra). true = bloquea imagenes fuera del repositorio interno"
  type        = bool
  default     = false
}

variable "extra_allowed_images" {
  description = "Patrones adicionales de imagenes permitidas"
  type        = list(string)
  default     = []
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
