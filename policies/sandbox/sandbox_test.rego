package main

import rego.v1

catalogo := {
	"limits": {"max_monthly_budget_usd": 5000, "max_days": 180, "gpu_types": ["l4", "a100", "h100"]},
	"profiles": {"rag": {"sizes": {"s": {"monthly_budget_usd": 300}, "m": {"monthly_budget_usd": 800}}}},
}

valido := {
	"name": "analitica",
	"owner_group": "gcp-analitica@example.com",
	"cost_center": "cc-1042",
	"expires": "2027-03-31",
	"profile": "rag",
	"size": "m",
	"subnet_index": 0,
}

errores(solicitud) := r if {
	r := deny with input as solicitud
		with data.limits as catalogo.limits
		with data.profiles as catalogo.profiles
		with data.today as "2026-12-01"
}

avisos(solicitud) := r if {
	r := warn with input as solicitud
		with data.limits as catalogo.limits
		with data.profiles as catalogo.profiles
		with data.today as "2026-12-01"
}

test_solicitud_valida if {
	count(errores(valido)) == 0
}

test_falta_campo if {
	count(errores(object.remove(valido, ["cost_center"]))) > 0
}

test_campo_extra_rechazado if {
	count(errores(object.union(valido, {"roles": ["roles/owner"]}))) == 1
}

test_cuenta_personal_rechazada if {
	count(errores(object.union(valido, {"owner_group": "ana.lopez@example.com"}))) == 1
}

test_perfil_inexistente if {
	count(errores(object.union(valido, {"profile": "mineria"}))) == 1
}

test_talla_inexistente if {
	count(errores(object.union(valido, {"size": "xl"}))) == 1
}

test_indice_fuera_de_rango if {
	count(errores(object.union(valido, {"subnet_index": 32}))) == 1
}

test_vigencia_excesiva if {
	count(errores(object.union(valido, {"expires": "2028-01-01"}))) == 1
}

test_vencido_avisa if {
	count(avisos(object.union(valido, {"expires": "2026-11-01"}))) == 1
}

test_presupuesto_sobre_tope if {
	count(errores(object.union(valido, {"monthly_budget_usd": 9000}))) == 1
}

test_presupuesto_ajustado_avisa if {
	count(errores(object.union(valido, {"monthly_budget_usd": 1200}))) == 0
	count(avisos(object.union(valido, {"monthly_budget_usd": 1200}))) == 1
}

test_h100_sin_aprobacion if {
	count(errores(object.union(valido, {"gpu_quota": {"h100": 1}}))) == 1
}

test_h100_con_aprobacion if {
	count(errores(object.union(valido, {"gpu_quota": {"h100": 1}, "aprobacion_h100": "CAB-218"}))) == 0
}

test_gpu_desconocida if {
	count(errores(object.union(valido, {"gpu_quota": {"v100": 1}}))) == 1
}
