# Decisiones de diseno

Registro breve de las decisiones que dan forma al repositorio y de lo que se descarto.

## 1. Etapas con estado y cuenta de servicio propios

**Decision.** Seis etapas que se aplican en orden. Cada una tiene su estado y una cuenta con los permisos minimos para lo que crea.

**Por que.** Un error en la etapa de sandboxes no puede tocar la red ni las llaves. Los planes son pequenos y se revisan mejor. Es la estructura del blueprint de fundaciones de Google.

**Descartado.** Un solo estado para todo: mas simple al inicio, pero cualquier cambio pone en riesgo toda la plataforma y exige una cuenta con permisos amplios.

## 2. Un proyecto por sandbox

**Decision.** Cada equipo recibe su propio proyecto.

**Por que.** El proyecto es el limite natural de permisos, cuotas y facturacion en Google Cloud. El costo por equipo sale de la factura sin instrumentar nada.

**Descartado.** Un proyecto compartido con espacios de nombres: ahorra administracion, pero mezcla costos y permisos.

## 3. Catalogo de perfiles y tallas

**Decision.** La solicitud de un equipo solo lleva siete datos. Servicios, permisos y acceso a datos salen del perfil; presupuesto y GPU, de la talla.

**Por que.** Quien pide un sandbox no necesita conocer Google Cloud, y no puede pedir permisos de mas porque la solicitud no tiene donde escribirlos. Cambiar un perfil actualiza todos los sandboxes que lo usan.

**Descartado.** Solicitudes libres con listas de APIs y roles: flexibles, pero cada una exige una revision de seguridad.

## 4. Costo por experimento desde la facturacion

**Decision.** El reparto de costos sale de la exportacion detallada de facturacion a BigQuery, con etiquetas de proyecto (equipo) y de solicitud (experimento).

**Por que.** Es el dato con el que Google cobra, asi que cuadra con la factura. Una vista adicional muestra el gasto sin etiquetar para que la cobertura se pueda medir.

**Descartado.** Calcular el costo desde el registro de prompts multiplicando tokens por precio: esa funcion sigue en vista previa, exige mantener una tabla de precios y no cuadra con descuentos ni creditos.

## 5. Cadena de suministro en dos pasos

**Decision.** Repositorios internos con escaneo, repositorios remotos para Docker Hub y PyPI, y Binary Authorization primero en modo de registro y despues en modo de bloqueo.

**Por que.** Los equipos de IA instalan muchas dependencias de terceros y ese es el camino mas comun de entrada de codigo malicioso. El modo de registro permite medir el impacto antes de bloquear.

**Descartado.** Bloquear desde el primer dia: detiene a los equipos antes de saber que usan. Firmas obligatorias con atestaciones: mas fuerte, pero requiere un proceso de compilacion maduro; queda como siguiente paso.

## 6. Perimetro en dos pasos

**Decision.** VPC Service Controls inicia en modo de prueba y pasa a obligatorio con un interruptor.

**Por que.** Un perimetro mal configurado detiene la plataforma completa. El modo de prueba registra lo que se bloquearia sin bloquearlo.

## 7. Apagar, no borrar

**Decision.** Al agotar el presupuesto, una funcion detiene GPU, notebooks y modelos desplegados. No elimina recursos ni datos.

**Por que.** Los presupuestos de Google solo avisan. Detener corta el gasto de computo, que es el que crece rapido, y se revierte en minutos.

**Descartado.** Desvincular la cuenta de facturacion del proyecto: corta todo el gasto, pero puede borrar recursos de forma irreversible.

## 8. GPU compartida, en Spot y a cero

**Decision.** Un cluster compartido con node pools que escalan a cero, Spot por defecto, GPU L4 compartida por tiempo para prototipos e inicio flexible para trabajos que pueden esperar.

**Por que.** La GPU es el mayor costo de la plataforma y la mayor parte del tiempo de un sandbox es inactivo.

## 9. Pipeline sin llaves

**Decision.** GitHub Actions se identifica con Workload Identity Federation, limitado a este repositorio.

**Por que.** Una llave de cuenta de servicio guardada como secreto es una credencial permanente que se puede filtrar. La identidad federada entrega credenciales de corta duracion.

## 10. Reglas como codigo antes del plan

**Decision.** Las solicitudes y los planes se revisan con reglas en Rego que tienen sus propias pruebas.

**Por que.** El error se detecta en el pull request, con un mensaje claro, y no en un despliegue fallido. Las mismas reglas documentan lo que la plataforma permite.

## Referencias

* [Blueprint de fundaciones empresariales](https://cloud.google.com/architecture/security-foundations)
* [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
* [Pruebas de Terraform con proveedores simulados](https://developer.hashicorp.com/terraform/language/tests/mocking)
* [Conftest](https://www.conftest.dev/)
