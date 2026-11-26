variable "name" {
  description = "Nombre del cluster"
  type        = string
}

variable "project_id" {
  description = "Proyecto ai-platform"
  type        = string
}

variable "region" {
  description = "Region del cluster"
  type        = string
}

variable "network_id" {
  description = "Id de la red compartida"
  type        = string
}

variable "subnet_id" {
  description = "Id de la subred de nodos"
  type        = string
}

variable "pods_range" {
  description = "Nombre del rango secundario de pods"
  type        = string
}

variable "services_range" {
  description = "Nombre del rango secundario de servicios"
  type        = string
}

variable "master_cidr" {
  description = "Rango /28 del plano de control"
  type        = string
  default     = "172.16.0.0/28"
}

variable "admin_range" {
  description = "Rango interno que puede llegar al plano de control"
  type        = string
  default     = "10.64.0.0/10"
}

variable "kms_key" {
  description = "Llave CMEK para discos y secretos del cluster"
  type        = string
}

variable "node_service_account" {
  description = "Cuenta de servicio de los nodos"
  type        = string
}

variable "gpu_node_pools" {
  description = "Node pools de GPU. shared_clients > 1 activa GPU compartida. flex_start activa el inicio flexible"
  type = map(object({
    machine_type   = string
    gpu_type       = string
    gpu_count      = number
    max_nodes      = number
    spot           = optional(bool, true)
    shared_clients = optional(number, 1)
    flex_start     = optional(bool, false)
  }))
}

variable "binary_authorization" {
  description = "Aplica la politica de Binary Authorization del proyecto"
  type        = bool
  default     = true
}

variable "node_tags" {
  description = "Secure tags de los nodos: tagKeys/... => tagValues/..."
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Protege el cluster contra borrado accidental"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
