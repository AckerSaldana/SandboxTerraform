# Costo por equipo y por experimento.
#
# Fuente: la exportacion detallada de facturacion a BigQuery, que incluye
# las etiquetas de proyecto y de recurso. Cada sandbox es un proyecto con
# las etiquetas team y cost_center, asi que el reparto por equipo sale de
# una consulta. Para el costo por experimento, los equipos envian la
# etiqueta "experimento" en cada llamada a Gemini y Google la reenvia a
# la facturacion.
#
# La exportacion se activa una sola vez, a mano, en la cuenta de
# facturacion. Mientras billing_export_table sea null, las vistas no se crean.

locals {
  views_enabled = var.billing_export_table != null
  export        = local.views_enabled ? "`${var.billing_export_table}`" : ""

  # Costo neto = costo menos creditos. Las etiquetas se leen del proyecto.
  base_cte = <<-SQL
    WITH base AS (
      SELECT
        DATE(usage_start_time) AS dia,
        project.id AS proyecto,
        (SELECT value FROM UNNEST(project.labels) WHERE key = 'team') AS equipo,
        (SELECT value FROM UNNEST(project.labels) WHERE key = 'cost_center') AS centro_costo,
        (SELECT value FROM UNNEST(labels) WHERE key = 'experimento') AS experimento,
        service.description AS servicio,
        sku.description AS sku,
        usage.amount_in_pricing_units AS uso,
        usage.pricing_unit AS unidad,
        cost + IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) AS c), 0) AS costo_neto
      FROM ${local.export}
    )
  SQL
}

resource "google_bigquery_dataset" "costs" {
  count       = local.views_enabled ? 1 : 0
  project     = var.views_project
  dataset_id  = "costos"
  location    = var.views_location
  description = "Vistas de costo por equipo y por experimento"
  labels      = var.labels

  default_encryption_configuration {
    kms_key_name = var.views_kms_key
  }
}

resource "google_bigquery_table" "by_team" {
  count               = local.views_enabled ? 1 : 0
  project             = var.views_project
  dataset_id          = google_bigquery_dataset.costs[0].dataset_id
  table_id            = "costo_por_equipo"
  description         = "Costo neto diario por equipo, centro de costos y servicio"
  deletion_protection = false

  view {
    use_legacy_sql = false
    query          = <<-SQL
      ${local.base_cte}
      SELECT dia, equipo, centro_costo, servicio, ROUND(SUM(costo_neto), 2) AS costo_usd
      FROM base
      WHERE equipo IS NOT NULL
      GROUP BY dia, equipo, centro_costo, servicio
    SQL
  }
}

resource "google_bigquery_table" "by_experiment" {
  count               = local.views_enabled ? 1 : 0
  project             = var.views_project
  dataset_id          = google_bigquery_dataset.costs[0].dataset_id
  table_id            = "costo_por_experimento"
  description         = "Costo neto diario por equipo y experimento, con el uso en la unidad de cobro"
  deletion_protection = false

  view {
    use_legacy_sql = false
    query          = <<-SQL
      ${local.base_cte}
      SELECT
        dia, equipo, experimento, sku, unidad,
        ROUND(SUM(uso), 2) AS uso,
        ROUND(SUM(costo_neto), 4) AS costo_usd,
        ROUND(SAFE_DIVIDE(SUM(costo_neto), SUM(uso)), 6) AS costo_por_unidad_usd
      FROM base
      WHERE experimento IS NOT NULL
      GROUP BY dia, equipo, experimento, sku, unidad
    SQL
  }
}

resource "google_bigquery_table" "untagged" {
  count               = local.views_enabled ? 1 : 0
  project             = var.views_project
  dataset_id          = google_bigquery_dataset.costs[0].dataset_id
  table_id            = "gasto_sin_experimento"
  description         = "Gasto de Vertex AI que los equipos no etiquetaron con un experimento"
  deletion_protection = false

  view {
    use_legacy_sql = false
    query          = <<-SQL
      ${local.base_cte}
      SELECT dia, equipo, sku, ROUND(SUM(costo_neto), 4) AS costo_usd
      FROM base
      WHERE equipo IS NOT NULL AND experimento IS NULL AND servicio = 'Vertex AI'
      GROUP BY dia, equipo, sku
    SQL
  }
}
