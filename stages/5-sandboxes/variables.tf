variable "tfstate_bucket" {
  description = "Bucket del estado de Terraform creado en 0-bootstrap"
  type        = string
}

variable "billing_account" {
  description = "Cuenta de facturacion"
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

variable "zone" {
  description = "Zona de los notebooks"
  type        = string
  default     = "us-central1-a"
}

variable "workbench_idle_minutes" {
  description = "Minutos de inactividad antes de apagar un notebook"
  type        = number
  default     = 60
}

variable "enforce_gpu_quota" {
  description = "Aplica la cuota de GPU de cada sandbox como limite de Compute Engine"
  type        = bool
  default     = false
}
