variable "endpoint_id" {
  description = "Id numerico del endpoint (hasta 10 digitos, sin ceros a la izquierda)"
  type        = string
}

variable "display_name" {
  description = "Nombre visible del endpoint"
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
  description = "Llave CMEK del endpoint"
  type        = string
}

variable "project_allowlist" {
  description = "Proyectos que pueden conectarse al endpoint por Private Service Connect"
  type        = list(string)
}

variable "prompt_log_dataset" {
  description = "Dataset para el registro de prompts, formato proyecto.dataset. null = sin registro"
  type        = string
  default     = null
}

variable "service_attachment" {
  description = "Adjunto de servicio del endpoint. Se conoce despues de desplegar un modelo"
  type        = string
  default     = null
}

variable "network_project" {
  description = "Proyecto net-hub"
  type        = string
}

variable "network_id" {
  description = "Id de la red compartida"
  type        = string
}

variable "psc_address" {
  description = "Direccion interna reservada en la etapa 3"
  type        = string
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
