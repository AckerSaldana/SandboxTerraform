# Reglas sobre el plan de Terraform de cualquier etapa:
#   terraform show -json plan.tfplan > plan.json
#   conftest test plan.json -p policies/terraform
package main

import rego.v1

cambios contains rc if {
	some rc in input.resource_changes
	some accion in rc.change.actions
	accion in {"create", "update"}
}

iam_types := {
	"google_project_iam_member", "google_project_iam_binding",
	"google_folder_iam_member", "google_folder_iam_binding",
	"google_organization_iam_member", "google_organization_iam_binding",
	"google_storage_bucket_iam_member", "google_storage_bucket_iam_binding",
	"google_bigquery_dataset_iam_member", "google_cloud_run_v2_service_iam_member",
}

miembros(rc) := {rc.change.after.member} if {
	rc.change.after.member
} else := {m | some m in rc.change.after.members}

# Nada publico
deny contains msg if {
	some rc in cambios
	rc.type in iam_types
	some m in miembros(rc)
	m in {"allUsers", "allAuthenticatedUsers"}
	msg := sprintf("%v da acceso publico (%v)", [rc.address, m])
}

# Sin roles basicos: ni owner ni editor
deny contains msg if {
	some rc in cambios
	rc.type in iam_types
	rc.change.after.role in {"roles/owner", "roles/editor"}
	msg := sprintf("%v usa el rol basico %v. Usar roles especificos", [rc.address, rc.change.after.role])
}

# Sin llaves de cuentas de servicio
deny contains msg if {
	some rc in cambios
	rc.type == "google_service_account_key"
	msg := sprintf("%v crea una llave de cuenta de servicio. Usar identidad federada", [rc.address])
}

# Buckets: acceso uniforme, sin acceso publico y con llave del cliente
deny contains msg if {
	some rc in cambios
	rc.type == "google_storage_bucket"
	rc.change.after.uniform_bucket_level_access != true
	msg := sprintf("%v debe usar acceso uniforme a nivel de bucket", [rc.address])
}

deny contains msg if {
	some rc in cambios
	rc.type == "google_storage_bucket"
	rc.change.after.public_access_prevention != "enforced"
	msg := sprintf("%v debe tener public_access_prevention = enforced", [rc.address])
}

deny contains msg if {
	some rc in cambios
	rc.type == "google_storage_bucket"
	count(object.get(rc.change.after, "encryption", [])) == 0
	msg := sprintf("%v no tiene llave CMEK", [rc.address])
}

deny contains msg if {
	some rc in cambios
	rc.type == "google_bigquery_dataset"
	count(object.get(rc.change.after, "default_encryption_configuration", [])) == 0
	msg := sprintf("%v no tiene llave CMEK", [rc.address])
}

# Sin IP publica en maquinas ni notebooks
deny contains msg if {
	some rc in cambios
	rc.type == "google_compute_instance"
	some nic in rc.change.after.network_interface
	count(object.get(nic, "access_config", [])) > 0
	msg := sprintf("%v tiene IP publica", [rc.address])
}

deny contains msg if {
	some rc in cambios
	rc.type == "google_workbench_instance"
	some gce in rc.change.after.gce_setup
	gce.disable_public_ip != true
	msg := sprintf("%v debe desactivar la IP publica", [rc.address])
}

# Todo proyecto lleva las etiquetas que alimentan el reparto de costos
etiquetas := ["team", "cost_center", "managed_by"]

deny contains msg if {
	some rc in cambios
	rc.type == "google_project"
	some e in etiquetas
	not object.get(rc.change.after, "labels", {})[e]
	msg := sprintf("%v no tiene la etiqueta '%v'", [rc.address, e])
}

# Reglas de firewall abiertas a Internet
deny contains msg if {
	some rc in cambios
	rc.type == "google_compute_firewall"
	rc.change.after.direction == "INGRESS"
	"0.0.0.0/0" in rc.change.after.source_ranges
	msg := sprintf("%v permite entrada desde 0.0.0.0/0", [rc.address])
}

# Borrados que merecen una segunda mirada
protegidos := {"google_project", "google_kms_crypto_key", "google_kms_key_ring", "google_bigquery_dataset", "google_storage_bucket"}

warn contains msg if {
	some rc in input.resource_changes
	"delete" in rc.change.actions
	rc.type in protegidos
	msg := sprintf("%v sera eliminado: confirmar en la revision", [rc.address])
}
