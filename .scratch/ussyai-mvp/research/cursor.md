# Viabilidad de Cursor para UssyAi

Fecha de consulta: 2026-09-23. Investigación documental; no se consultó ninguna cuenta, credencial, Keychain ni base privada local. El borrador es una hipótesis de producto. Rama de trabajo huérfana `research/ussyai-cursor`, worktree `/tmp/ussyai-research-cursor`; sin commits porque el repositorio carece de commit inicial.

## Resultado

**Viabilidad documental condicionada, pendiente de validación con la cuenta real.** Hay una implementación pública que consulta cuotas con la sesión existente; no encontramos en las páginas oficiales consultadas un contrato público para esos RPC y REST personales. No debe prometerse estabilidad ni compatibilidad con todos los planes. La API pública de administración es otra integración: usa API key mediante Basic Authentication y sirve datos del equipo, no equivale a reutilizar automáticamente la sesión personal. [Admin API oficial](https://cursor.com/docs/account/teams/admin-api).

## Hechos oficiales sobre las cuotas

La documentación vigente describe dos bolsas separadas, **Cursor Models** y **Other Models**, que reinician con el ciclo mensual de facturación. Pro, Pro Plus y Ultra incluyen ambas; Start incluye solo la primera. El consumo depende del modelo; al agotar la cuota puede haber uso adicional facturado. Teams y Enterprise tienen condiciones diferentes, y aún existen planes heredados basados en solicitudes. Las bolsas se ven en los ajustes del editor y en el dashboard. Por tanto, el precio nominal de una suscripción no es un denominador universal ni se deben sumar porcentajes de bolsas distintas. Esta última frase es una conclusión para UssyAi. [Models & Pricing oficial](https://cursor.com/docs/models-and-pricing).

## Sesión local: evidencia de código, no contrato de Cursor

OpenUsage se revisó en el commit **`4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4`**. Su almacén lee `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`, con claves `cursorAuth/accessToken`, `cursorAuth/refreshToken` y `cursorAuth/stripeMembershipType`; también consulta servicios Keychain `cursor-access-token` y `cursor-refresh-token`. Da preferencia a SQLite salvo una excepción que compara sujetos JWT cuando SQLite parece una cuenta gratuita y Keychain otra cuenta. Ese caso evidencia riesgo de fuentes discordantes; no prueba que esa heurística sea adecuada para UssyAi. El mismo código puede escribir un access token renovado. [CursorAuthStore.swift, revisión fija](https://github.com/robinebers/openusage/blob/4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4/Sources/OpenUsage/Providers/Cursor/CursorAuthStore.swift).

**Propuesta para el MVP:** leer únicamente el access token necesario y metadatos mínimos de selección; nunca renovar ni escribir. Si las fuentes indican cuentas diferentes, no elegir silenciosamente otra cuenta. Mostrar sesión no verificable y guiar al usuario a Cursor. Esta propuesta requiere decisión posterior; no se probaron los permisos de acceso en esta Mac.

## Consultas observadas

El cliente público implementa:

| Finalidad | Ruta y forma |
|---|---|
| Uso principal | `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage` |
| Plan opcional | `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetPlanInfo` |
| Respaldo por solicitudes | `GET https://cursor.com/api/usage?user=<id>` |
| Resumen complementario | `GET https://cursor.com/api/usage-summary` |

RPC: JSON `{}`, Bearer y `Connect-Protocol-Version: 1`. REST: cookie `WorkosCursorSessionToken` construida con el identificador extraído del sujeto JWT y el access token. Son mecanismos de OpenUsage, sin garantía oficial encontrada. Otras rutas del cliente consultan Grok Bot, créditos, Stripe y exportación CSV; no son necesarias para las cuotas básicas acordadas. [CursorUsageClient.swift](https://github.com/robinebers/openusage/blob/4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4/Sources/OpenUsage/Providers/Cursor/CursorUsageClient.swift).

OpenUsage selecciona el respaldo por forma del uso/plan y combina los dos REST; las consultas opcionales pueden fallar sin invalidar el resultado principal. También renueva anticipadamente y reintenta el uso principal tras problemas de autenticación. **UssyAi no debe copiar esa renovación:** una consulta semánticamente de lectura puede usar POST, pero el endpoint OAuth de renovación queda excluido. [CursorProvider.swift](https://github.com/robinebers/openusage/blob/4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4/Sources/OpenUsage/Providers/Cursor/CursorProvider.swift).

## Interpretación y denominadores

En RPC, el mapper reconoce `planUsage.totalPercentUsed`, `autoPercentUsed` y `apiPercentUsed`; interpreta los dos últimos como Cursor Models y Other Models. También trata `totalSpend`, `limit` y `remaining` como centavos y usa `billingCycleStart`/`billingCycleEnd` como epoch en milisegundos. Hay variantes de gasto adicional individual o compartido. Esto describe el código tercero, no un esquema publicado por Cursor. [CursorUsageMapper.swift](https://github.com/robinebers/openusage/blob/4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4/Sources/OpenUsage/Providers/Cursor/CursorUsageMapper.swift).

En REST, el código combina `gpt-4.numRequests` o `numRequestsTotal` con `maxRequestUsage`; el nombre histórico `gpt-4` no debe interpretarse automáticamente como una cuota exclusiva de ese modelo. El resumen contiene `individualUsage.plan`, variantes individuales/compartidas y límites del ciclo en ISO 8601. OpenUsage prioriza el cupo de solicitudes cuando existe. [CursorUsageSummaryMapper.swift](https://github.com/robinebers/openusage/blob/4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4/Sources/OpenUsage/Providers/Cursor/CursorUsageSummaryMapper.swift).

Reglas propuestas de UssyAi, sujetas a decisión de normalización:

- Aceptar porcentaje explícito solo cuando se valide qué bolsa representa. No fabricar un total a partir de las dos bolsas.
- Calcular `100 × usado / límite` únicamente con valores presentes, finitos, unidades iguales, límite positivo y mismo sujeto/ciclo. Un monto gastado o un conteo sin límite permite un valor, nunca un porcentaje.
- No copiar defaults a cero del mapper tercero: una ausencia debe seguir ausente. Conservar el valor recibido aunque el medidor visual tenga un máximo.
- No atribuir cuota o gasto del equipo a la persona. Para este MVP personal, omitirlo o etiquetarlo inequívocamente según la decisión posterior.
- Mostrar reinicio solo con fecha válida entregada por el servidor. No calcularlo como “ahora + 30 días” ni asumir el primer día del mes.
- No añadir historial/costos al MVP por el hecho de que los endpoints devuelvan dinero. Los importes pueden servir internamente como denominador validado de cuota.

## Restricciones y validación pendiente

La investigación no demuestra autorización contractual general para reutilizar endpoints internos ni sus límites de frecuencia; no se revisaron exhaustivamente términos de servicio. No se debe equiparar “existe código público” con “API soportada”. Mantener el adaptador sustituible y un estado no disponible es coherente con la aceptación del usuario de integraciones parciales.

Antes de considerar Cursor compatible: identificar plan/cuenta activa; confirmar fuente de sesión sin registrar secretos; comprobar acceso de solo lectura con la app empaquetada; contrastar cada bolsa y reinicio con el dashboard oficial; verificar formatos, unidades y ámbito personal/equipo; simular sesión vencida, cuota omitida y respuesta parcial; verificar que una actualización no escribe credenciales ni contacta OAuth, CSV, Stripe o servicios ajenos. La comprobación debe usar datos normalizados y registros de categoría, no respuestas crudas.

## Preguntas precisas que quedan

1. ¿Qué plan de Cursor usa esta Mac y muestra una o dos bolsas, o un cupo heredado de solicitudes?
2. ¿La tarjeta debe mostrar ambas bolsas cuando existan y omitir un total cuyo significado no esté verificado?
3. Si solo se reciben métricas de equipo o importes sin denominador, ¿se presentan con su unidad/ámbito o se deja la cuota personal no disponible?
4. ¿Qué estado y recuperación se usarán cuando SQLite y Keychain apunten a cuentas distintas?

## Fuentes locales leídas

`app-macos-uso-claude-codex-cursor.md`, el ticket `03-viabilidad-cursor.md` y `/Users/cronos/.agents/skills/research/SKILL.md`. Las copias Swift en el worktree proceden exclusivamente del repositorio público citado; no son archivos privados de la aplicación instalada. Las fuentes oficiales son páginas mutables consultadas en la fecha indicada; la referencia OpenUsage queda fijada por commit.
