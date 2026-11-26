variable "prefix" {
  description = "Prefijo de la empresa"
  type        = string
}

variable "name" {
  description = "Nombre del equipo"
  type        = string
}

variable "host_project" {
  description = "Proyecto anfitrion de la Shared VPC"
  type        = string
}

variable "network_id" {
  description = "Id de la red compartida"
  type        = string
}

variable "region" {
  description = "Region de la subred"
  type        = string
}

variable "cidr" {
  description = "Bloque /16 del sandbox"
  type        = string
}

variable "users" {
  description = "Quien puede usar la subred: etiqueta estatica => member"
  type        = map(string)
  default     = {}
}

variable "flow_sampling" {
  description = "Muestreo de flow logs"
  type        = number
  default     = 0.1
}
