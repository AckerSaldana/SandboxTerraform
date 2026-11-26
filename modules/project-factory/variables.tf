variable "prefix" {
  description = "Prefijo de la empresa para los nombres"
  type        = string
}

variable "name" {
  description = "Nombre corto del proyecto (el id queda como <prefijo>-aisbx-<nombre>)"
  type        = string
}

variable "folder_id" {
  description = "Carpeta donde se crea el proyecto"
  type        = string
}

variable "billing_account" {
  description = "Cuenta de facturacion"
  type        = string
}

variable "services" {
  description = "APIs que se habilitan en el proyecto"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Etiquetas del proyecto (team, owner, cost_center, expires, managed_by)"
  type        = map(string)
}

variable "shared_vpc_host" {
  description = "Proyecto anfitrion de la Shared VPC. Si es null, el proyecto no se conecta"
  type        = string
  default     = null
}

variable "deletion_policy" {
  description = "PREVENT para la base, DELETE para sandboxes que deben borrarse limpio"
  type        = string
  default     = "PREVENT"
}
