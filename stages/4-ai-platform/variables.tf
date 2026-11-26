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

variable "allowed_models" {
  description = "Modelos permitidos, formato publishers/<editor>/models/<modelo>:<predict|deploy|tune>. Ajustar a los modelos vigentes"
  type        = list(string)
  default = [
    "publishers/google/models/gemini-2.5-pro:predict",
    "publishers/google/models/gemini-2.5-flash:predict",
    "publishers/google/models/gemini-2.5-flash:tune",
    "publishers/google/models/text-embedding-005:predict",
    "publishers/meta/models/llama3:deploy",
    "publishers/hf-google/models/gemma-2b:deploy",
  ]
}

variable "gpu_node_pools" {
  description = "Node pools de GPU del cluster compartido. Todos escalan a cero"
  type = map(object({
    machine_type   = string
    gpu_type       = string
    gpu_count      = number
    max_nodes      = number
    spot           = optional(bool, true)
    shared_clients = optional(number, 1)
    flex_start     = optional(bool, false)
  }))
  default = {
    # Prototipos y notebooks: hasta 4 cargas comparten cada L4
    l4-compartida = {
      machine_type   = "g2-standard-8"
      gpu_type       = "nvidia-l4"
      gpu_count      = 1
      max_nodes      = 4
      shared_clients = 4
    }
    # Inferencia y ajuste fino ligero en Spot
    l4-spot = {
      machine_type = "g2-standard-16"
      gpu_type     = "nvidia-l4"
      gpu_count    = 1
      max_nodes    = 8
    }
    # Ajuste fino que puede esperar capacidad: inicio flexible
    a100-flex = {
      machine_type = "a2-highgpu-1g"
      gpu_type     = "nvidia-tesla-a100"
      gpu_count    = 1
      max_nodes    = 4
      spot         = false
      flex_start   = true
    }
  }
}

variable "enable_tpu" {
  description = "Crea el node pool de TPU (solo bajo solicitud y con cuota aprobada)"
  type        = bool
  default     = false
}

variable "tpu_zones" {
  description = "Zonas con capacidad de TPU"
  type        = list(string)
  default     = ["us-central1-a"]
}

variable "binauthz_enforced" {
  description = "false = Binary Authorization en modo de prueba. true = bloquea imagenes fuera del repositorio interno"
  type        = bool
  default     = false
}

variable "prompt_log_retention_days" {
  description = "Dias que se conserva el registro de prompts"
  type        = number
  default     = 90
}

variable "endpoint_service_attachment" {
  description = "Adjunto de servicio del endpoint privado. Se conoce despues de desplegar el primer modelo"
  type        = string
  default     = null
}

variable "enable_vector_search" {
  description = "Crea el indice de Vector Search del piloto RAG"
  type        = bool
  default     = false
}

variable "deploy_vector_index" {
  description = "Despliega el indice en un endpoint. Genera costo fijo por nodo"
  type        = bool
  default     = false
}

variable "agent_image" {
  description = "Imagen del agente piloto en Artifact Registry. null = solo se crea la identidad"
  type        = string
  default     = null
}

variable "cost_guard_dry_run" {
  description = "true = la funcion de apagado solo registra lo que detendria"
  type        = bool
  default     = false
}

variable "billing_export_table" {
  description = "Tabla de la exportacion detallada de facturacion (proyecto.dataset.tabla). null = no crear vistas de costo"
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Permite destruir la etapa con datos dentro. Solo para pruebas de despliegue desde cero"
  type        = bool
  default     = false
}
