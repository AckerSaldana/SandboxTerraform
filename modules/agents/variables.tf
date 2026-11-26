variable "name" {
  description = "Nombre del servicio del agente"
  type        = string
  default     = "agente"
}

variable "project_id" {
  description = "Proyecto ai-platform"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
}

variable "image" {
  description = "Imagen del agente en Artifact Registry. null = solo se crea la identidad"
  type        = string
  default     = null
}

variable "max_instances" {
  description = "Maximo de instancias"
  type        = number
  default     = 2
}

variable "kms_key" {
  description = "Llave CMEK del servicio"
  type        = string
  default     = null
}

variable "network_id" {
  description = "Id de la red compartida"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Id de la subred"
  type        = string
  default     = null
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
