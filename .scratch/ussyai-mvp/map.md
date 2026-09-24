# Definir el MVP de UssyAi

Label: wayfinder:map
Status: open

## Destination

Dejar una especificación del MVP de UssyAi lista para implementar: alcance, viabilidad de integraciones, significado de las métricas, comportamiento de la interfaz y criterios de aceptación decididos.

## Notes

- Planificación; la implementación de la app queda para un esfuerzo posterior.
- Base revisable: [borrador original](../../app-macos-uso-claude-codex-cursor.md). Sus afirmaciones técnicas requieren verificación; no son garantías de acceso a las cuentas reales.
- Acuerdos del usuario al trazar el mapa: app personal para una Mac, barra de menús con icono fijo, tarjetas de Claude, Codex y Cursor, cuotas usadas/restantes y reinicios. La primera versión puede ser útil con integraciones parciales; una integración indisponible conserva su tarjeta y explica el estado.
- Límites de partida del borrador: reutilizar sesiones existentes en lectura, sin login propio, modificación de credenciales, backend, telemetría ni sincronización. Separar cada cuota, nunca inventar un porcentaje combinado o convertir un dato ausente en cero.
- Consultar wayfinder y domain-modeling en cada sesión; grilling para decisiones con el usuario, research para investigación y prototype para discusión visual. Vocabulario: [CONTEXT.md](../../CONTEXT.md).
- Tracker local: un archivo por ticket en `issues/`; `Parent: ../map.md`; etiquetas `wayfinder:<tipo>`; `Status: open`, `claimed` o `resolved`; `Assignee: unassigned` o responsable. Reclamar antes de trabajar. `Blocked by` contiene los identificadores locales de las dependencias. La frontera se consulta por número: abierto, sin asignar y con todas las dependencias resueltas. Resolver añade `## Answer`, cierra el ticket y enlaza aquí su conclusión; no duplicar la respuesta.
- Entorno observado el 2026-09-23: macOS 27.0, arm64, Swift 6.4 y Command Line Tools seleccionadas. Esto no fija todavía el objetivo mínimo ni el empaquetado.
- Las investigaciones consultan documentación y código públicos; no leen secretos ni prueban sesiones privadas. Las conclusiones distinguirán evidencia pública de validación pendiente con la cuenta real.

## Decisions so far

<!-- Solo tickets resueltos: conclusión breve y enlace al lugar donde vive la respuesta. -->

- [Determinar qué cuotas de Claude pueden consultarse en lectura](issues/01-viabilidad-claude.md): la vía interna de Claude Code es técnicamente plausible; Desktop y la adopción de OAuth requieren una decisión explícita.
- [Determinar qué cuotas de Codex pueden consultarse en lectura](issues/02-viabilidad-codex.md): existe una consulta interna pasiva; el app-server puede renovar credenciales y las ventanas y almacenes varían.
- [Determinar qué cuotas de Cursor pueden consultarse en lectura](issues/03-viabilidad-cursor.md): hay RPC y respaldo REST internos; las bolsas y planes requieren validación sin inventar un total combinado.

## Not yet specified

- La estrategia de mantenimiento ante cambios en interfaces no públicas depende de la fragilidad observada en cada integración.

## Out of scope

- Implementar o distribuir la app durante este mapa: el destino es una especificación lista para construir.
- Historial de tokens, costos monetarios, consumo facturado de API y comparaciones de precios: el MVP trata cuotas de suscripción actuales.
- Múltiples cuentas, otros proveedores, sincronización, servidor y telemetría.
- Renovación automática y escritura de credenciales en el MVP.
