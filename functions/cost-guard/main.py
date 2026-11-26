"""Apagado por presupuesto.

Recibe las notificaciones de Cloud Billing Budgets por Pub/Sub. Cuando un
sandbox llega al umbral configurado (100 % por defecto) detiene lo que
genera gasto de computo en su proyecto:

  1. Maquinas virtuales con GPU.
  2. Instancias de Vertex AI Workbench.
  3. Modelos desplegados en endpoints de Vertex AI.

No borra datos ni recursos: solo los detiene. El equipo los reanuda
cuando el lider amplia el presupuesto con un pull request.

El nombre de cada presupuesto es el id del proyecto del sandbox, que
siempre contiene "-aisbx-" (ver modules/sandbox-factory).
"""

import base64
import json
import logging
import os

import functions_framework
import google.auth
from googleapiclient import discovery

REGION = os.environ.get("REGION", "us-central1")
STOP_AT = float(os.environ.get("STOP_AT_THRESHOLD", "1.0"))
DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("cost-guard")


def _clients():
    credentials, _ = google.auth.default()
    compute = discovery.build("compute", "v1", credentials=credentials, cache_discovery=False)
    notebooks = discovery.build("notebooks", "v2", credentials=credentials, cache_discovery=False)
    vertex = discovery.build(
        "aiplatform",
        "v1",
        credentials=credentials,
        cache_discovery=False,
        client_options={"api_endpoint": f"https://{REGION}-aiplatform.googleapis.com"},
    )
    return compute, notebooks, vertex


def stop_gpu_instances(compute, project):
    """Detiene las VM con GPU que esten encendidas."""
    stopped = []
    request = compute.instances().aggregatedList(project=project)
    while request is not None:
        response = request.execute()
        for scope in response.get("items", {}).values():
            for vm in scope.get("instances", []):
                if vm.get("status") != "RUNNING" or not vm.get("guestAccelerators"):
                    continue
                zone = vm["zone"].rsplit("/", 1)[-1]
                stopped.append(f"{zone}/{vm['name']}")
                if not DRY_RUN:
                    compute.instances().stop(project=project, zone=zone, instance=vm["name"]).execute()
        request = compute.instances().aggregatedList_next(request, response)
    return stopped


def stop_workbench(notebooks, project):
    """Detiene las instancias de Workbench activas."""
    stopped = []
    parent = f"projects/{project}/locations/-"
    request = notebooks.projects().locations().instances().list(parent=parent)
    while request is not None:
        response = request.execute()
        for instance in response.get("instances", []):
            if instance.get("state") != "ACTIVE":
                continue
            stopped.append(instance["name"])
            if not DRY_RUN:
                notebooks.projects().locations().instances().stop(name=instance["name"], body={}).execute()
        request = notebooks.projects().locations().instances().list_next(request, response)
    return stopped


def undeploy_models(vertex, project):
    """Retira los modelos desplegados. El endpoint queda vacio y deja de cobrar."""
    undeployed = []
    parent = f"projects/{project}/locations/{REGION}"
    endpoints = vertex.projects().locations().endpoints()
    request = endpoints.list(parent=parent)
    while request is not None:
        response = request.execute()
        for endpoint in response.get("endpoints", []):
            for model in endpoint.get("deployedModels", []):
                undeployed.append(f"{endpoint['name']}#{model['id']}")
                if not DRY_RUN:
                    endpoints.undeployModel(
                        endpoint=endpoint["name"], body={"deployedModelId": model["id"]}
                    ).execute()
        request = endpoints.list_next(request, response)
    return undeployed


def parse_notification(cloud_event):
    """Devuelve (proyecto, fraccion gastada) o (None, 0) si el mensaje no aplica."""
    message = cloud_event.data.get("message", {})
    payload = json.loads(base64.b64decode(message.get("data", "")).decode("utf-8") or "{}")

    budget = float(payload.get("budgetAmount", 0) or 0)
    cost = float(payload.get("costAmount", 0) or 0)
    name = payload.get("budgetDisplayName", "")

    # Solo se actua sobre presupuestos creados por la fabrica de sandboxes
    if budget <= 0 or "-aisbx-" not in name:
        return None, 0.0

    return name, cost / budget


@functions_framework.cloud_event
def on_budget(cloud_event):
    project, spent = parse_notification(cloud_event)
    if not project:
        log.info("Mensaje ignorado: no es un presupuesto de sandbox")
        return

    if spent < STOP_AT:
        log.info("Proyecto %s al %.0f %% de su presupuesto. Sin accion.", project, spent * 100)
        return

    compute, notebooks, vertex = _clients()
    result = {
        "proyecto": project,
        "gasto_pct": round(spent * 100, 1),
        "simulacion": DRY_RUN,
        "vm_gpu": stop_gpu_instances(compute, project),
        "workbench": stop_workbench(notebooks, project),
        "modelos": undeploy_models(vertex, project),
    }
    log.warning("Presupuesto agotado. Recursos detenidos: %s", json.dumps(result))
