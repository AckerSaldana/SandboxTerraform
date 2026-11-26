variable "team" {
  description = "Sandbox ya resuelto: el YAML del equipo combinado con su perfil y su talla"
  type = object({
    name               = string
    owner_group        = string
    cost_center        = string
    expires            = string
    profile            = string
    size               = string
    subnet_index       = number
    monthly_budget_usd = number
    gpu_quota          = map(number)
    services           = list(string)
    roles              = list(string)
    data_access        = list(string)
    workbench          = bool
  })

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,14}$", var.team.name))
    error_message = "El nombre del equipo debe tener de 3 a 15 caracteres: minusculas, digitos y guion medio."
  }

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", var.team.expires))
    error_message = "La fecha de expiracion debe tener el formato AAAA-MM-DD."
  }

  validation {
    condition     = !contains(var.team.data_access, "raw")
    error_message = "La zona raw nunca se comparte con un sandbox."
  }

  validation {
    condition     = var.team.subnet_index >= 0 && var.team.subnet_index <= 31
    error_message = "El indice de subred va de 0 a 31 (32 sandboxes)."
  }
}

variable "prefix" {
  description = "Prefijo de la empresa"
  type        = string
}

variable "folder_id" {
  description = "Carpeta ai-sandbox"
  type        = string
}

variable "billing_account" {
  description = "Cuenta de facturacion"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
}

variable "zone" {
  description = "Zona para los notebooks"
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

variable "sandbox_range" {
  description = "Rango del que cada sandbox toma su /16"
  type        = string
  default     = "10.96.0.0/11"
}

variable "kms_keys" {
  description = "Mapa servicio => id de llave"
  type        = map(string)
}

variable "perimeter_name" {
  description = "Nombre completo del perimetro de VPC Service Controls"
  type        = string
}

variable "perimeter_enforced" {
  description = "Indica si el perimetro esta en modo obligatorio"
  type        = bool
}

variable "budget_topic" {
  description = "Tema de Pub/Sub de los presupuestos"
  type        = string
}

variable "platform_project" {
  description = "Proyecto ai-platform"
  type        = string
}

variable "data_project" {
  description = "Proyecto ai-data"
  type        = string
}

variable "curated_bucket" {
  description = "Bucket de la zona curated"
  type        = string
}

variable "curated_dataset" {
  description = "Dataset de la zona curated"
  type        = string
}

variable "workbench_idle_minutes" {
  description = "Minutos de inactividad antes de apagar el notebook"
  type        = number
  default     = 60
}

variable "enforce_gpu_quota" {
  description = "Aplica la cuota de GPU del sandbox como limite de Compute Engine. Verificar antes los nombres de gpu_quota_metrics con gcloud"
  type        = bool
  default     = false
}

variable "gpu_quota_metrics" {
  description = "Metrica de cuota de Compute Engine por tipo de GPU"
  type        = map(string)
  default = {
    l4   = "compute.googleapis.com/nvidia_l4_gpus"
    a100 = "compute.googleapis.com/nvidia_a100_gpus"
    h100 = "compute.googleapis.com/nvidia_h100_gpus"
  }
}
