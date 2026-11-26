variable "name" {
  description = "Nombre de la instancia"
  type        = string
}

variable "project_id" {
  description = "Proyecto del sandbox"
  type        = string
}

variable "zone" {
  description = "Zona de la instancia"
  type        = string
}

variable "network_id" {
  description = "Id de la red compartida"
  type        = string
}

variable "subnet_id" {
  description = "Id de la subred del sandbox"
  type        = string
}

variable "machine_type" {
  description = "Tipo de maquina"
  type        = string
  default     = "e2-standard-4"
}

variable "gpu_type" {
  description = "Tipo de GPU, por ejemplo NVIDIA_L4. null = sin GPU"
  type        = string
  default     = null
}

variable "data_disk_gb" {
  description = "Tamano del disco de datos"
  type        = number
  default     = 100
}

variable "idle_minutes" {
  description = "Minutos de inactividad antes de apagar la instancia"
  type        = number
  default     = 60
}

variable "kms_key" {
  description = "Llave CMEK para los discos"
  type        = string
}

variable "service_account" {
  description = "Cuenta de servicio de la instancia"
  type        = string
}

variable "owners" {
  description = "Usuario dueno de la instancia (maximo uno)"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
