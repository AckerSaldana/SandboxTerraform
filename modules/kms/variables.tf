variable "project_id" {
  description = "Proyecto security donde viven las llaves"
  type        = string
}

variable "location" {
  description = "Region del llavero"
  type        = string
}

variable "keyring_name" {
  description = "Nombre del llavero"
  type        = string
}

variable "keys" {
  description = "Nombres de las llaves, una por servicio"
  type        = set(string)
}

variable "rotation_period" {
  description = "Periodo de rotacion (90 dias por defecto)"
  type        = string
  default     = "7776000s"
}

variable "encrypters" {
  description = "Permisos de uso: etiqueta estatica => { key, member }"
  type = map(object({
    key    = string
    member = string
  }))
  default = {}
}
