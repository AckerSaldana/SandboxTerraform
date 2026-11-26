#!/usr/bin/env bash
# Pruebas del perimetro de VPC Service Controls y de las politicas de
# organizacion. Se ejecutan despues del despliegue, con una identidad del
# grupo de plataforma.
#
# Uso: PREFIX=acme ./tests/perimetro.sh
set -uo pipefail

: "${PREFIX:?Definir PREFIX}"
PLATFORM="${PREFIX}-aisbx-ai-platform"
DATA="${PREFIX}-aisbx-ai-data"
fallas=0

ok()   { echo "  OK    $1"; }
mal()  { echo "  FALLA $1"; fallas=$((fallas + 1)); }

# espera_falla <descripcion> <comando...>: el comando debe ser rechazado
espera_falla() {
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then mal "$d"; else ok "$d"; fi
}

espera_exito() {
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else mal "$d"; fi
}

echo "1. La zona raw no se puede leer desde fuera del perimetro"
espera_falla "listar raw desde esta maquina" gcloud storage ls "gs://${PREFIX}-aisbx-raw"

echo "2. No se pueden crear llaves de cuentas de servicio"
espera_falla "crear llave" gcloud iam service-accounts keys create /tmp/llave.json \
  --iam-account "sa-gke-nodos@${PLATFORM}.iam.gserviceaccount.com"

echo "3. No se pueden crear recursos fuera de las regiones permitidas"
espera_falla "bucket en europa" gcloud storage buckets create "gs://${PREFIX}-aisbx-prueba-eu" \
  --project "$PLATFORM" --location europe-west1

echo "4. No se pueden crear recursos sin llave CMEK"
espera_falla "bucket sin CMEK" gcloud storage buckets create "gs://${PREFIX}-aisbx-prueba-sin-cmek" \
  --project "$PLATFORM" --location us-central1

echo "5. No se pueden crear maquinas con IP publica"
espera_falla "VM con IP publica" gcloud compute instances create prueba-ip-publica \
  --project "$PLATFORM" --zone us-central1-a --machine-type e2-micro \
  --network-interface "subnet=projects/${PREFIX}-aisbx-net-hub/regions/us-central1/subnetworks/${PREFIX}-aisbx-ai-platform"

echo "6. Los proyectos estan dentro del perimetro"
POLITICA="$(gcloud access-context-manager policies list --organization "${ORG_ID:-0}" --format 'value(name)' 2>/dev/null | head -1)"
if [ -n "$POLITICA" ]; then
  espera_exito "perimetro existe" gcloud access-context-manager perimeters describe "${PERIMETRO:-aisbx}" --policy "$POLITICA"
else
  echo "  OMITIDA definir ORG_ID para revisar el perimetro"
fi

echo "7. Solo se pueden usar modelos de la lista permitida"
espera_exito "politica vertexai.allowedModels" gcloud org-policies describe vertexai.allowedModels \
  --project "$PLATFORM" --effective

echo
if [ "$fallas" -gt 0 ]; then echo "$fallas pruebas fallaron"; exit 1; fi
echo "Todas las pruebas pasaron"
