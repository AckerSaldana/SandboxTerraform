variable "org_id" {
  description = "Id numerico de la organizacion"
  type        = string
}

variable "billing_account" {
  description = "Cuenta de facturacion"
  type        = string
}

variable "tfstate_bucket" {
  description = "Bucket del estado de Terraform creado en 0-bootstrap"
  type        = string
}

variable "prefix" {
  description = "Prefijo de la empresa"
  type        = string
}

variable "region" {
  description = "Region principal"
  type        = string
  default     = "us-central1"
}

variable "alt_region" {
  description = "Region alterna"
  type        = string
  default     = "us-east4"
}

variable "cost_center" {
  description = "Centro de costos de la plataforma"
  type        = string
  default     = "plataforma"
}

variable "platform_group" {
  description = "Grupo del equipo de plataforma (correo)"
  type        = string
}

variable "data_owners_group" {
  description = "Grupo que aprueba el acceso temporal a los datos (correo)"
  type        = string
}
