# Lista de modelos permitidos. Un modelo fuera de la lista se rechaza en
# la API de Vertex AI, no solo en el pull request.
#
# Formato de cada valor: publishers/<editor>/models/<modelo>:<accion>
#   predict = inferencia en modelos con API administrada (Gemini)
#   deploy  = despliegue de modelos abiertos desde Model Garden
#   tune    = ajuste fino
resource "google_org_policy_policy" "allowed_models" {
  name   = "${var.parent}/policies/vertexai.allowedModels"
  parent = var.parent

  spec {
    rules {
      values {
        allowed_values = var.allowed_models
      }
    }
  }
}
