# Reglas de una solicitud de sandbox (stages/5-sandboxes/teams/*.yaml).
# Corren en el pull request, antes de cualquier plan:
#   conftest test stages/5-sandboxes/teams/*.yaml -p policies/sandbox -d stages/5-sandboxes/profiles.yaml
package main

import rego.v1

required := ["name", "owner_group", "cost_center", "expires", "profile", "size", "subnet_index"]

allowed := {"name", "owner_group", "cost_center", "expires", "profile", "size", "subnet_index", "monthly_budget_usd", "gpu_quota", "aprobacion_h100"}

deny contains msg if {
	some field in required
	not field in object.keys(input)
	msg := sprintf("Falta el campo obligatorio '%s'", [field])
}

deny contains msg if {
	some field, _ in input
	not field in allowed
	msg := sprintf("Campo no permitido: '%s'. Servicios, permisos y datos se definen en el perfil, no en la solicitud", [field])
}

deny contains msg if {
	not regex.match(`^[a-z][a-z0-9-]{2,14}$`, input.name)
	msg := sprintf("Nombre invalido '%v': de 3 a 15 caracteres, minusculas, digitos y guion medio", [input.name])
}

# El responsable es un grupo, nunca una persona: los permisos sobreviven
# a los cambios de personal
deny contains msg if {
	not regex.match(`^(gcp|grp|team|equipo)-[a-z0-9-]+@[a-z0-9.-]+$`, input.owner_group)
	msg := sprintf("owner_group '%v' debe ser un grupo (gcp-<equipo>@dominio), no una cuenta personal", [input.owner_group])
}

deny contains msg if {
	not regex.match(`^cc-[0-9]{4}$`, input.cost_center)
	msg := sprintf("cost_center '%v' debe tener el formato cc-0000", [input.cost_center])
}

deny contains msg if {
	not data.profiles[input.profile]
	msg := sprintf("El perfil '%v' no existe. Perfiles: %v", [input.profile, concat(", ", sort(object.keys(data.profiles)))])
}

deny contains msg if {
	data.profiles[input.profile]
	not data.profiles[input.profile].sizes[input.size]
	msg := sprintf("La talla '%v' no existe en el perfil '%v'", [input.size, input.profile])
}

deny contains msg if {
	not is_number(input.subnet_index)
	msg := "subnet_index debe ser un numero"
}

deny contains msg if {
	is_number(input.subnet_index)
	not valid_index
	msg := sprintf("subnet_index %v fuera de rango: de 0 a 31", [input.subnet_index])
}

valid_index if {
	input.subnet_index >= 0
	input.subnet_index <= 31
	input.subnet_index == floor(input.subnet_index)
}

# Vigencia: todo sandbox caduca
expires_ns := time.parse_ns("2006-01-02", input.expires)

deny contains msg if {
	not regex.match(`^\d{4}-\d{2}-\d{2}$`, sprintf("%v", [input.expires]))
	msg := sprintf("expires '%v' debe tener el formato AAAA-MM-DD, entre comillas", [input.expires])
}

deny contains msg if {
	limit := today_ns + (((data.limits.max_days * 24) * 3600) * 1000000000)
	expires_ns > limit
	msg := sprintf("La vigencia supera el maximo de %v dias. Los sandboxes se renuevan, no se crean sin fecha de fin", [data.limits.max_days])
}

warn contains msg if {
	expires_ns < today_ns
	msg := sprintf("El sandbox '%v' ya vencio (%v): renovar la fecha o eliminar el archivo", [input.name, input.expires])
}

# Ajustes sobre la talla
deny contains msg if {
	input.monthly_budget_usd > data.limits.max_monthly_budget_usd
	msg := sprintf("Presupuesto %v USD supera el tope de %v USD", [input.monthly_budget_usd, data.limits.max_monthly_budget_usd])
}

deny contains msg if {
	input.monthly_budget_usd <= 0
	msg := "El presupuesto debe ser mayor que cero"
}

deny contains msg if {
	some gpu, _ in input.gpu_quota
	not gpu in data.limits.gpu_types
	msg := sprintf("Tipo de GPU desconocido: '%v'", [gpu])
}

deny contains msg if {
	input.gpu_quota.h100 > 0
	not input.aprobacion_h100
	msg := "La GPU H100 requiere el campo aprobacion_h100 con la referencia de la aprobacion"
}

warn contains msg if {
	base := data.profiles[input.profile].sizes[input.size].monthly_budget_usd
	input.monthly_budget_usd > base
	msg := sprintf("Presupuesto ajustado de %v a %v USD: requiere visto bueno de la plataforma", [base, input.monthly_budget_usd])
}

# La fecha de hoy se puede fijar en las pruebas con data.today
today_ns := time.parse_ns("2006-01-02", data.today) if {
	data.today
} else := time.now_ns()
