"""Pruebas de la funcion de apagado por presupuesto, sin tocar GCP.

Uso: python3 -m unittest discover -s tests
"""
import base64
import importlib.util
import json
import pathlib
import sys
import types
import unittest
from unittest import mock

RAIZ = pathlib.Path(__file__).resolve().parent.parent


def cargar_funcion():
    """Carga main.py con las bibliotecas de Google sustituidas."""
    ff = types.ModuleType("functions_framework")
    ff.cloud_event = lambda f: f
    google = types.ModuleType("google")
    google.auth = types.ModuleType("google.auth")
    api = types.ModuleType("googleapiclient")
    api.discovery = types.ModuleType("googleapiclient.discovery")
    sys.modules.update({
        "functions_framework": ff,
        "google": google,
        "google.auth": google.auth,
        "googleapiclient": api,
        "googleapiclient.discovery": api.discovery,
    })
    spec = importlib.util.spec_from_file_location("cost_guard", RAIZ / "functions" / "cost-guard" / "main.py")
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def evento(nombre, costo, presupuesto):
    datos = json.dumps({"budgetDisplayName": nombre, "costAmount": costo, "budgetAmount": presupuesto})
    return types.SimpleNamespace(data={"message": {"data": base64.b64encode(datos.encode()).decode()}})


class CostGuard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.f = cargar_funcion()

    def test_presupuesto_de_sandbox(self):
        proyecto, gasto = self.f.parse_notification(evento("acme-aisbx-vision", 750, 1500))
        self.assertEqual(proyecto, "acme-aisbx-vision")
        self.assertAlmostEqual(gasto, 0.5)

    def test_ignora_presupuestos_ajenos(self):
        proyecto, _ = self.f.parse_notification(evento("presupuesto-general", 900, 1000))
        self.assertIsNone(proyecto)

    def test_ignora_presupuesto_cero(self):
        proyecto, _ = self.f.parse_notification(evento("acme-aisbx-vision", 10, 0))
        self.assertIsNone(proyecto)

    def test_mensaje_vacio(self):
        proyecto, _ = self.f.parse_notification(types.SimpleNamespace(data={}))
        self.assertIsNone(proyecto)

    def test_bajo_el_umbral_no_detiene(self):
        with mock.patch.object(self.f, "_clients") as clientes:
            self.f.on_budget(evento("acme-aisbx-vision", 1200, 1500))
            clientes.assert_not_called()

    def test_al_cien_por_ciento_detiene(self):
        with mock.patch.object(self.f, "_clients", return_value=(1, 2, 3)), \
             mock.patch.object(self.f, "stop_gpu_instances", return_value=["z/vm"]) as vm, \
             mock.patch.object(self.f, "stop_workbench", return_value=[]) as nb, \
             mock.patch.object(self.f, "undeploy_models", return_value=[]) as modelos:
            self.f.on_budget(evento("acme-aisbx-vision", 1500, 1500))
            vm.assert_called_once_with(1, "acme-aisbx-vision")
            nb.assert_called_once_with(2, "acme-aisbx-vision")
            modelos.assert_called_once_with(3, "acme-aisbx-vision")


if __name__ == "__main__":
    unittest.main()
