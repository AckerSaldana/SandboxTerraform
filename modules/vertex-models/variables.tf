variable "parent" {
  description = "Carpeta o proyecto donde aplica la lista (folders/NUMERO o projects/ID)"
  type        = string
}

variable "allowed_models" {
  description = "Modelos permitidos, formato publishers/<editor>/models/<modelo>:<accion>"
  type        = list(string)

  validation {
    condition     = alltrue([for m in var.allowed_models : can(regex("^publishers/[^/]+/models/[^:]+:(predict|deploy|tune)$", m))])
    error_message = "Cada modelo debe tener el formato publishers/<editor>/models/<modelo>:<predict|deploy|tune>."
  }
}
