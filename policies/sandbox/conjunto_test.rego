package conjunto

import rego.v1

test_indices_distintos if {
	count(deny) == 0 with input as [
		{"path": "teams/a.yaml", "contents": {"name": "a", "subnet_index": 0}},
		{"path": "teams/b.yaml", "contents": {"name": "b", "subnet_index": 1}},
	]
}

test_indice_repetido if {
	count(deny) == 1 with input as [
		{"path": "teams/a.yaml", "contents": {"name": "a", "subnet_index": 4}},
		{"path": "teams/b.yaml", "contents": {"name": "b", "subnet_index": 4}},
	]
}

test_archivo_distinto_del_nombre if {
	count(deny) == 1 with input as [{"path": "teams/a.yaml", "contents": {"name": "otro", "subnet_index": 0}}]
}
