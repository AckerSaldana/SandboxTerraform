variable "prefix" {
  description = "Prefijo de la empresa"
  type        = string
}

variable "project_id" {
  description = "Proyecto net-hub (anfitrion de la Shared VPC)"
  type        = string
}

variable "subnets" {
  description = "Subredes base del plan de IP: nombre => { cidr, region, secondary_ranges }"
  type = map(object({
    cidr             = string
    region           = string
    secondary_ranges = optional(map(string), {})
  }))
}

variable "flow_sampling" {
  description = "Muestreo de flow logs (0.1 = 10 %)"
  type        = number
  default     = 0.1
}
