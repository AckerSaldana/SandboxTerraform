package main

import rego.v1

rc(tipo, despues) := {"resource_changes": [{
	"address": sprintf("%v.x", [tipo]),
	"type": tipo,
	"change": {"actions": ["create"], "after": despues},
}]}

bucket_ok := {
	"uniform_bucket_level_access": true,
	"public_access_prevention": "enforced",
	"encryption": [{"default_kms_key_name": "k"}],
}

test_bucket_correcto if {
	count(deny) == 0 with input as rc("google_storage_bucket", bucket_ok)
}

test_bucket_sin_cmek if {
	count(deny) == 1 with input as rc("google_storage_bucket", object.remove(bucket_ok, ["encryption"]))
}

test_bucket_publico if {
	count(deny) == 1 with input as rc("google_storage_bucket", object.union(bucket_ok, {"public_access_prevention": "inherited"}))
}

test_acceso_publico if {
	count(deny) == 1 with input as rc("google_storage_bucket_iam_member", {"member": "allUsers", "role": "roles/storage.objectViewer"})
}

test_rol_basico if {
	count(deny) == 1 with input as rc("google_project_iam_member", {"member": "group:a@example.com", "role": "roles/owner"})
}

test_rol_especifico if {
	count(deny) == 0 with input as rc("google_project_iam_member", {"member": "group:a@example.com", "role": "roles/aiplatform.user"})
}

test_llave_de_cuenta_de_servicio if {
	count(deny) == 1 with input as rc("google_service_account_key", {})
}

test_ip_publica if {
	count(deny) == 1 with input as rc("google_compute_instance", {"network_interface": [{"access_config": [{}]}]})
}

test_notebook_con_ip_publica if {
	count(deny) == 1 with input as rc("google_workbench_instance", {"gce_setup": [{"disable_public_ip": false}]})
}

test_proyecto_sin_etiquetas if {
	count(deny) == 2 with input as rc("google_project", {"labels": {"team": "vision"}})
}

test_proyecto_con_etiquetas if {
	count(deny) == 0 with input as rc("google_project", {"labels": {"team": "vision", "cost_center": "cc-1", "managed_by": "terraform"}})
}

test_firewall_abierto if {
	count(deny) == 1 with input as rc("google_compute_firewall", {"direction": "INGRESS", "source_ranges": ["0.0.0.0/0"]})
}

test_borrado_avisa if {
	count(warn) == 1 with input as {"resource_changes": [{"address": "google_project.x", "type": "google_project", "change": {"actions": ["delete"], "after": null}}]}
}
