variable "name" {
  description = "Nombre del indice"
  type        = string
}

variable "project_id" {
  description = "Proyecto ai-platform"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
}

variable "contents_uri" {
  description = "Carpeta de Cloud Storage con los embeddings iniciales (gs://bucket/carpeta)"
  type        = string
}

variable "dimensions" {
  description = "Dimensiones del embedding"
  type        = number
  default     = 768
}

variable "deploy" {
  description = "Despliega el indice en un endpoint. Genera costo fijo por nodo"
  type        = bool
  default     = false
}

variable "machine_type" {
  description = "Tipo de maquina del indice desplegado"
  type        = string
  default     = "e2-standard-2"
}

variable "max_replicas" {
  description = "Maximo de replicas"
  type        = number
  default     = 1
}

variable "project_allowlist" {
  description = "Proyectos que pueden consultar el indice por Private Service Connect"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Etiquetas"
  type        = map(string)
  default     = {}
}
