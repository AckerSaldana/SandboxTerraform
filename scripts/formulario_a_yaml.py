#!/usr/bin/env python3
"""Convierte una solicitud (issue de GitHub) en el archivo YAML del equipo.

El cuerpo del issue llega por la variable de entorno ISSUE_BODY. El script
valida el formato de cada respuesta, asigna el primer subnet_index libre
y escribe stages/5-sandboxes/teams/<equipo>.yaml. Las reglas de negocio
las revisa despues conftest en el pull request.
"""
import os
import pathlib
import re
import sys

import yaml

TEAMS = pathlib.Path(__file__).resolve().parent.parent / "stages" / "5-sandboxes" / "teams"

CAMPOS = {
    "Nombre del equipo": ("name", r"[a-z][a-z0-9-]{2,14}"),
    "Grupo responsable": ("owner_group", r"[a-z0-9-]+@[a-z0-9.-]+"),
    "Centro de costos": ("cost_center", r"cc-[0-9]{4}"),
    "Fecha de fin": ("expires", r"\d{4}-\d{2}-\d{2}"),
    "Perfil": ("profile", r"[a-z-]+"),
    "Talla": ("size", r"[sml]"),
}


def leer_formulario(cuerpo):
    """Los formularios de GitHub generan bloques '### Titulo' + respuesta."""
    respuestas = {}
    for bloque in re.split(r"^### ", cuerpo, flags=re.M)[1:]:
        titulo, _, resto = bloque.partition("\n")
        respuestas[titulo.strip()] = resto.strip().splitlines()[0].strip() if resto.strip() else ""
    return respuestas


def construir(respuestas):
    equipo, errores = {}, []
    for titulo, (campo, patron) in CAMPOS.items():
        valor = respuestas.get(titulo, "")
        # Solo se aceptan valores con el formato exacto: nada del issue
        # llega al repositorio sin pasar por estas expresiones
        if not re.fullmatch(patron, valor):
            errores.append(f"{titulo}: valor invalido")
        equipo[campo] = valor
    return equipo, errores


def indice_libre(carpeta):
    usados = {yaml.safe_load(f.read_text()).get("subnet_index") for f in carpeta.glob("*.yaml")}
    for i in range(32):
        if i not in usados:
            return i
    raise SystemExit("No quedan bloques de red libres (32 sandboxes).")


def main():
    carpeta = pathlib.Path(os.environ.get("TEAMS_DIR", TEAMS))
    equipo, errores = construir(leer_formulario(os.environ.get("ISSUE_BODY", "")))
    if errores:
        print("\n".join(errores))
        return 1

    destino = carpeta / f"{equipo['name']}.yaml"
    if destino.exists():
        print(f"El equipo {equipo['name']} ya tiene un sandbox. Para cambiarlo, editar su archivo.")
        return 1

    equipo["subnet_index"] = indice_libre(carpeta)
    destino.write_text(yaml.safe_dump(equipo, sort_keys=False, allow_unicode=True))
    print(destino.name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
