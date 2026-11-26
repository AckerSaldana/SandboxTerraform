#!/usr/bin/env python3
"""Lista los sandboxes vencidos o por vencer.

Uso: python3 scripts/expiraciones.py [--dias 14] [--hoy AAAA-MM-DD]

Imprime un reporte en Markdown. Termina con codigo 1 si hay algo que
atender, para que el flujo programado abra un issue.
"""
import argparse
import datetime as dt
import pathlib
import sys

import yaml

TEAMS = pathlib.Path(__file__).resolve().parent.parent / "stages" / "5-sandboxes" / "teams"


def clasificar(equipos, hoy, dias):
    vencidos, proximos = [], []
    for e in equipos:
        fin = dt.date.fromisoformat(str(e["expires"]))
        restante = (fin - hoy).days
        if restante < 0:
            vencidos.append((e, restante))
        elif restante <= dias:
            proximos.append((e, restante))
    return vencidos, proximos


def reporte(vencidos, proximos):
    lineas = []
    if vencidos:
        lineas += ["## Sandboxes vencidos", "", "| Equipo | Responsable | Vencio | Dias |", "|---|---|---|---|"]
        lineas += [f"| {e['name']} | {e['owner_group']} | {e['expires']} | {abs(d)} |" for e, d in vencidos]
        lineas += ["", "Accion: eliminar `stages/5-sandboxes/teams/<equipo>.yaml` en un pull request o renovar la fecha.", ""]
    if proximos:
        lineas += ["## Sandboxes por vencer", "", "| Equipo | Responsable | Vence | Dias |", "|---|---|---|---|"]
        lineas += [f"| {e['name']} | {e['owner_group']} | {e['expires']} | {d} |" for e, d in proximos]
        lineas += ["", "Accion: avisar al responsable. Si el sandbox sigue en uso, renovar la fecha en un pull request.", ""]
    return "\n".join(lineas)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dias", type=int, default=14)
    p.add_argument("--hoy", default=None)
    p.add_argument("--carpeta", default=str(TEAMS))
    a = p.parse_args()

    hoy = dt.date.fromisoformat(a.hoy) if a.hoy else dt.date.today()
    equipos = [yaml.safe_load(f.read_text()) for f in sorted(pathlib.Path(a.carpeta).glob("*.yaml"))]
    vencidos, proximos = clasificar(equipos, hoy, a.dias)

    if not vencidos and not proximos:
        print("Sin sandboxes vencidos ni por vencer.")
        return 0
    print(reporte(vencidos, proximos))
    return 1


if __name__ == "__main__":
    sys.exit(main())
