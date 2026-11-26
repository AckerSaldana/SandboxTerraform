# Guia para equipos

## 1. Elegir perfil y talla

El perfil dice para que se usara el sandbox. La talla dice cuanto necesita. Los valores vigentes estan en [`stages/5-sandboxes/profiles.yaml`](../stages/5-sandboxes/profiles.yaml).

| Perfil | Para que sirve | Notebook | Datos | GPU |
|---|---|---|---|---|
| `rag` | Busqueda y respuestas sobre documentos con modelos administrados | Si | curated | Solo talla l |
| `finetuning` | Ajuste fino de modelos | Si | curated | Si |
| `modelos-abiertos` | Despliegue de modelos abiertos en endpoints privados | No | Ninguno | Si |
| `ml-clasico` | Modelos tabulares y analitica | Si | curated | No |
| `agentes` | Agentes sobre Cloud Run con modelos administrados | No | curated | No |

| Talla | Presupuesto mensual (USD) segun el perfil |
|---|---|
| `s` | 200 a 600 |
| `m` | 500 a 1,500 |
| `l` | 1,200 a 4,000 |

Si ninguna talla alcanza, la solicitud puede incluir `monthly_budget_usd` o `gpu_quota`. Esos ajustes pasan por revision de la plataforma y tienen un tope de 5,000 USD al mes. La GPU H100 exige ademas el campo `aprobacion_h100`.

## 2. Pedir el sandbox

Opcion A: abrir un issue con el formulario "Solicitud de sandbox". Un flujo genera el archivo y abre el pull request.

Opcion B: crear `stages/5-sandboxes/teams/<equipo>.yaml` en un pull request:

```yaml
name: fraude                          # 3 a 15 caracteres; igual al nombre del archivo
owner_group: gcp-fraude@example.com   # un grupo, nunca una persona
cost_center: cc-3301
expires: "2027-04-30"                 # maximo 180 dias
profile: ml-clasico
size: s
subnet_index: 2                       # numero libre de 0 a 31
```

Para revisar la solicitud antes de enviarla:

```bash
conftest test stages/5-sandboxes/teams/fraude.yaml -p policies/sandbox -d stages/5-sandboxes/profiles.yaml
```

## 3. Que recibe el equipo

* Un proyecto `<prefijo>-aisbx-<equipo>` dentro del perimetro de seguridad.
* Una subred propia en la red compartida, sin IP publicas.
* Una cuenta de servicio `sa-<equipo>` para sus cargas de trabajo.
* Lectura de la zona `curated` (datos ya anonimizados) si el perfil la incluye. La zona `raw` nunca se comparte.
* Lectura de los repositorios internos de imagenes y paquetes.
* Un notebook de Vertex AI Workbench si el perfil lo incluye. Se apaga solo tras 60 minutos sin uso.
* Un presupuesto mensual con avisos al 50, 80 y 100 %.

El equipo usa la plataforma, pero no administra red, llaves ni permisos.

## 4. Reglas de uso

**Imagenes y paquetes.** Solo desde los repositorios internos. Docker Hub y PyPI se consumen a traves de repositorios remotos que guardan copia y escanean vulnerabilidades:

```bash
pip install --index-url https://us-central1-python.pkg.dev/<prefijo>-aisbx-ai-platform/pypi-remoto/simple/ pandas
docker pull us-central1-docker.pkg.dev/<prefijo>-aisbx-ai-platform/dockerhub-remoto/library/python:3.12-slim
```

**Modelos.** Solo los de la lista permitida. Para agregar uno, pull request sobre `allowed_models` en la etapa 4.

**GPU.** Los node pools escalan a cero y usan Spot. Los trabajos deben tolerar interrupciones y guardar puntos de control.

**Presupuesto.** Al llegar al 100 %, la plataforma detiene las maquinas con GPU, los notebooks y los modelos desplegados del sandbox. No borra nada. Para reanudar, el responsable amplia el presupuesto con un pull request.

**Vigencia.** Catorce dias antes del vencimiento se abre un aviso. Un sandbox vencido se renueva cambiando `expires` o se elimina borrando su archivo.

## 5. Etiquetar los experimentos

El costo por equipo sale solo, porque cada sandbox es un proyecto etiquetado. Para conocer ademas el costo de cada experimento, hay que enviar la etiqueta `experimento` en cada llamada o trabajo.

Llamadas a Gemini:

```python
from google import genai
from google.genai import types

client = genai.Client(vertexai=True, project="<proyecto>", location="us-central1")
client.models.generate_content(
    model="gemini-2.5-flash",
    contents="...",
    config=types.GenerateContentConfig(labels={"experimento": "resumen-contratos-v2"}),
)
```

Trabajos de entrenamiento y endpoints: usar el parametro `labels` del recurso con la misma clave.

Reglas de las etiquetas: minusculas, digitos, guion medio y guion bajo; hasta 63 caracteres. Las etiquetas en llamadas a Gemini aplican al consumo de pago por uso y tardan cerca de un dia en aparecer en la facturacion.

## 6. Consultar el gasto

Las vistas viven en el dataset `costos` del proyecto de registros:

| Vista | Responde |
|---|---|
| `costo_por_equipo` | Cuanto gasto cada equipo y centro de costos, por dia y servicio |
| `costo_por_experimento` | Cuanto costo cada experimento y cuanto uso tuvo |
| `gasto_sin_experimento` | Que gasto de Vertex AI quedo sin etiquetar |

```sql
SELECT equipo, experimento, ROUND(SUM(costo_neto), 2) AS usd
FROM `<prefijo>-aisbx-logging.costos.costo_por_experimento`
WHERE dia >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY equipo, experimento
ORDER BY usd DESC;
```

## Referencias

* [Etiquetas en llamadas a la API de Gemini](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/add-labels-to-api-calls)
* [Exportacion de facturacion a BigQuery](https://cloud.google.com/billing/docs/how-to/export-data-bigquery)
* [Repositorios remotos de Artifact Registry](https://cloud.google.com/artifact-registry/docs/repositories/remote-repo)
* [GPU compartida por tiempo en GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/timesharing-gpus)
