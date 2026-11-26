# Runbooks

Procedimientos de operacion. Todo cambio se hace con un pull request; la consola se usa solo para consultar.

## 1. Pasar el perimetro de prueba a obligatorio

1. Dejar `perimeter_enforced = false` al menos una semana con los equipos trabajando.
2. Revisar las violaciones registradas:

   ```sql
   SELECT protopayload_auditlog.serviceName AS servicio,
          protopayload_auditlog.authenticationInfo.principalEmail AS identidad,
          COUNT(*) AS veces
   FROM `<prefijo>-aisbx-logging.vpcsc_violaciones.cloudaudit_googleapis_com_policy`
   GROUP BY servicio, identidad
   ORDER BY veces DESC;
   ```

3. Por cada acceso legitimo, agregar la regla de entrada o salida en `modules/vpc-sc`. Por cada acceso indebido, corregir la carga de trabajo.
4. Cuando la consulta solo muestre accesos que deben bloquearse, cambiar a `true` en `stages/2-security/config.auto.tfvars`.
5. Aplicar las etapas 2, 4 y 5 en ese orden: las ultimas dos mueven sus proyectos del modo de prueba al obligatorio.
6. Ejecutar `tests/perimetro.sh`.

Para volver atras: regresar el valor a `false` y aplicar de nuevo.

## 2. Activar el bloqueo de imagenes

1. Con `binauthz_enforced = false`, Binary Authorization registra cada imagen que bloquearia. Revisar en Cloud Logging:

   ```
   logName:"binaryauthorization.googleapis.com" AND protoPayload.response.reason="VIOLATES_POLICY"
   ```

   Usar el filtro como punto de partida y ajustarlo a los campos que muestre el registro.
2. Mover al repositorio interno las imagenes que aparezcan, o consumirlas por `dockerhub-remoto`.
3. Cambiar a `true` en `stages/4-ai-platform/config.auto.tfvars`.

Las imagenes del sistema de GKE quedan permitidas por la politica.

## 3. Un sandbox agoto su presupuesto

Sintoma: el equipo reporta que sus notebooks, maquinas con GPU o endpoints se detuvieron.

1. Confirmar en los registros de la funcion `cost-guard` el mensaje "Presupuesto agotado" con la lista de recursos detenidos.
2. Revisar en que se fue el gasto con la vista `costo_por_experimento`.
3. Si el gasto es legitimo, el responsable abre un pull request con `monthly_budget_usd` mayor o con otra talla. Al aprobarse, el equipo reanuda sus recursos.
4. Si no lo es, el sandbox permanece detenido hasta el mes siguiente.

La funcion detiene, nunca borra. Durante la primera semana conviene mantener `cost_guard_dry_run = true` y revisar que solo registra lo esperado.

## 4. Un sandbox vencio

1. El flujo `programados` abre o actualiza el issue "Sandboxes vencidos o por vencer".
2. Avisar al grupo responsable.
3. Renovar: pull request que cambia `expires` (maximo 180 dias).
4. Retirar: pull request que borra `stages/5-sandboxes/teams/<equipo>.yaml`. Terraform elimina el proyecto; Google lo conserva 30 dias antes de borrarlo en definitiva.

## 5. Acceso de emergencia

Nadie tiene permisos permanentes de administrador. El grupo de plataforma solicita un permiso temporal con Privileged Access Manager, con justificacion y aprobacion. La concesion vence sola y queda en los registros de auditoria.

## 6. Agregar un modelo a la lista permitida

Pull request sobre `allowed_models` en `stages/4-ai-platform`, con el formato `publishers/<editor>/models/<modelo>:<predict|deploy|tune>`.

## 7. Desviacion entre el codigo y lo desplegado

El flujo `programados` falla los lunes si alguna etapa tiene cambios pendientes. Revisar el resumen del plan: si alguien cambio algo a mano, decidir entre llevar el cambio al codigo o dejar que el siguiente despliegue lo revierta.

## 8. Rotacion de llaves

Las llaves CMEK rotan solas segun el periodo definido en `modules/kms`. No hay llaves de cuentas de servicio que rotar: una politica de organizacion impide crearlas y el pipeline se identifica con Workload Identity Federation.

## 9. Destruir todo (solo entornos de prueba)

En orden inverso, de la etapa 5 a la 0, con `force_destroy = true` en la etapa 4. El perimetro debe estar en modo de prueba.

## Referencias

* [Modo de prueba de VPC Service Controls](https://cloud.google.com/vpc-service-controls/docs/dry-run-mode)
* [Binary Authorization](https://cloud.google.com/binary-authorization/docs)
* [Notificaciones programaticas de presupuestos](https://cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications)
* [Privileged Access Manager](https://cloud.google.com/iam/docs/pam-overview)
