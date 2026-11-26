variable "name" {
  description = "Nombre del node pool"
  type        = string
  default     = "tpu-v5e"
}

variable "project_id" {
  description = "Proyecto ai-platform"
  type        = string
}

variable "region" {
  description = "Region del cluster"
  type        = string
}

variable "cluster_name" {
  description = "Cluster donde se agrega el node pool"
  type        = string
}

variable "zones" {
  description = "Zonas con capacidad de TPU"
  type        = list(string)
}

variable "machine_type" {
  description = "Tipo de maquina con TPU (ct5lp-hightpu-4t = TPU v5e de 4 chips)"
  type        = string
  default     = "ct5lp-hightpu-4t"
}

variable "tpu_topology" {
  description = "Topologia para TPU de varios hosts, por ejemplo 2x4. null = un solo host"
  type        = string
  default     = null
}

variable "max_nodes" {
  description = "Maximo de nodos"
  type        = number
  default     = 2
}

variable "spot" {
  description = "Usa capacidad Spot"
  type        = bool
  default     = true
}

variable "kms_key" {
  description = "Llave CMEK para los discos"
  type        = string
}

variable "node_service_account" {
  description = "Cuenta de servicio de los nodos"
  type        = string
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
