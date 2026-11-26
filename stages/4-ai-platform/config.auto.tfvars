# Interruptores de la etapa. Se cambian con un pull request.

# Cadena de suministro. false: Binary Authorization solo registra las
# imagenes que bloquearia. true: bloquea todo lo que no venga del
# repositorio interno.
binauthz_enforced = false

# Apagado por presupuesto. true: la funcion solo registra lo que detendria.
# Pasar a false despues de revisar los registros de la primera semana.
cost_guard_dry_run = true

# Costo por equipo y por experimento. Activar la exportacion detallada de
# facturacion a BigQuery (una vez, en la consola) y poner aqui la tabla.
# billing_export_table = "proyecto.dataset.gcp_billing_export_resource_v1_XXXXXX_XXXXXX_XXXXXX"

# Piloto RAG. El indice desplegado tiene costo fijo por nodo.
enable_vector_search = false
deploy_vector_index  = false
