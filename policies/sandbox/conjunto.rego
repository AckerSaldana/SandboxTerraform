# Reglas que miran todas las solicitudes a la vez:
#   conftest test --combine --namespace conjunto stages/5-sandboxes/teams/*.yaml -p policies/sandbox
package conjunto

import rego.v1

deny contains msg if {
	some i, j
	i < j
	input[i].contents.subnet_index == input[j].contents.subnet_index
	msg := sprintf("%v y %v comparten subnet_index %v", [input[i].path, input[j].path, input[i].contents.subnet_index])
}

deny contains msg if {
	some i, j
	i < j
	input[i].contents.name == input[j].contents.name
	msg := sprintf("%v y %v comparten el nombre '%v'", [input[i].path, input[j].path, input[i].contents.name])
}

deny contains msg if {
	some item in input
	archivo := trim_suffix(array.reverse(split(item.path, "/"))[0], ".yaml")
	archivo != item.contents.name
	msg := sprintf("%v: el nombre del archivo debe coincidir con name ('%v')", [item.path, item.contents.name])
}
