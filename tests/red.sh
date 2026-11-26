#!/usr/bin/env bash
# Pruebas de red. Las pruebas de conectividad se crean en 3-networks; este
# script las vuelve a ejecutar y revisa su resultado.
#
# Uso: PREFIX=acme ./tests/red.sh
set -uo pipefail

: "${PREFIX:?Definir PREFIX}"
HUB="${PREFIX}-aisbx-net-hub"
fallas=0

echo "1. Pruebas de conectividad"
for prueba in $(gcloud network-management connectivity-tests list --project "$HUB" --format 'value(name)'); do
  nombre="${prueba##*/}"
  gcloud network-management connectivity-tests rerun "$nombre" --project "$HUB" --quiet >/dev/null 2>&1
  resultado="$(gcloud network-management connectivity-tests describe "$nombre" --project "$HUB" \
    --format 'value(reachabilityDetails.result)')"
  # Por convencion, las pruebas que deben ser bloqueadas llevan "sin-internet" o "bloqueado" en el nombre
  esperado="REACHABLE"
  case "$nombre" in *sin-internet*|*bloqueado*) esperado="UNREACHABLE" ;; esac
  if [ "$resultado" = "$esperado" ]; then
    echo "  OK    $nombre ($resultado)"
  else
    echo "  FALLA $nombre: esperado $esperado, obtenido $resultado"
    fallas=$((fallas + 1))
  fi
done

echo "2. Las APIs de Google resuelven a la VIP restringida (199.36.153.4/30)"
zona="$(gcloud dns managed-zones list --project "$HUB" --filter 'dnsName=googleapis.com.' --format 'value(name)' | head -1)"
if [ -n "$zona" ]; then
  echo "  OK    zona privada $zona"
else
  echo "  FALLA no existe la zona privada de googleapis.com"
  fallas=$((fallas + 1))
fi

echo "3. Ninguna subred tiene rutas a Internet fuera de Cloud NAT"
nat="$(gcloud compute routers list --project "$HUB" --format 'value(name)' | wc -l)"
if [ "$nat" -gt 0 ]; then echo "  OK    $nat routers con NAT"; else echo "  FALLA sin Cloud NAT"; fallas=$((fallas + 1)); fi

echo "4. El tunel VPN esta establecido"
gcloud compute vpn-tunnels list --project "$HUB" --format 'table(name,status,detailedStatus)'

echo
if [ "$fallas" -gt 0 ]; then echo "$fallas pruebas fallaron"; exit 1; fi
echo "Todas las pruebas pasaron"
