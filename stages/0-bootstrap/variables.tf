variable "org_id" {
  description = "Id numerico de la organizacion"
  type        = string
}

variable "billing_account" {
  description = "Cuenta de facturacion, formato XXXXXX-XXXXXX-XXXXXX"
  type        = string
}

variable "prefix" {
  description = "Prefijo de la empresa para los nombres (minusculas, maximo 6 caracteres)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,5}$", var.prefix))
    error_message = "El prefijo debe empezar con letra y tener de 2 a 6 caracteres en minusculas o digitos."
  }
}

variable "region" {
  description = "Region principal"
  type        = string
  default     = "us-central1"
}

variable "github_repo" {
  description = "Repositorio permitido en Workload Identity Federation, formato dueno/repositorio"
  type        = string
}

variable "cost_center" {
  description = "Centro de costos de la plataforma"
  type        = string
  default     = "plataforma"
}
