# Viabilidad de lectura de cuotas de Claude

Investigación: 2026-09-23. Alcance: documentación y código público; no se leyeron credenciales, sesiones ni variables sensibles de esta Mac y no se consultó la cuenta real.

## Resultado

Existe una integración técnicamente plausible mediante una sesión de Claude Code y una ruta OAuth interna, demostrada por OpenUsage. No se encontró un contrato público para consultar por esa vía las cuotas de una suscripción personal. La viabilidad con esta cuenta y la adecuación del reuso de OAuth a este caso concreto siguen sin validar. Claude Desktop añade descifrado y dependencia de formatos privados: merece una decisión separada, no un requisito automático del MVP.

## Hechos oficiales

- Claude Code guarda las credenciales en Keychain de macOS; si no puede escribir allí puede usar `.credentials.json` con permisos 0600. `CLAUDE_CONFIG_DIR` modifica tanto la ubicación del archivo como la identidad de la entrada Keychain. El inicio con claude.ai es distinto del acceso Console/API/cloud; tener cualquier OAuth no prueba que corresponda a una suscripción personal. [Autenticación de Claude Code](https://code.claude.com/docs/en/authentication).
- Las cuotas de Claude se comparten entre web, Code y Desktop. Dependen del plan y del uso; no equivalen a un número fijo de mensajes o tokens. [Límites de uso](https://support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work).
- Anthropic describe límites de cinco horas y semanales, con reinicios otorgados ocasionalmente que pueden alterar el estado antes del reinicio habitual. UssyAi no debe recalcular ni activar esos reinicios: debe volver a consultar. [Qué es un reinicio de límite](https://support.claude.com/en/articles/17007452-what-is-a-limit-reset).

## Restricciones documentadas y límite de la interpretación

La documentación oficial dice que OAuth está diseñado para el uso ordinario de Claude Code y aplicaciones nativas de Anthropic. Prohíbe ofrecer login Claude.ai en aplicaciones de terceros y enrutar solicitudes con credenciales de usuarios de Free/Pro/Max. Añade: “developers may not collect, store, or intermediate Claude.ai credentials or session tokens”. [Authentication and credential use](https://code.claude.com/docs/en/legal-and-compliance#authentication-and-credential-use).

Es un texto más amplio que una mera restricción de inferencia, pero **no menciona explícitamente la consulta de cuotas por una herramienta personal local de solo lectura**. Por ello no concluyo que este caso esté expresamente permitido ni universalmente prohibido. Tampoco que el código MIT de OpenUsage otorgue permiso sobre el servicio. Pregunta de decisión posterior: ¿se incluye Claude con el mecanismo interno, sujeto a aclarar su adecuación al caso, o se conserva por ahora una tarjeta informativa con acceso a la pantalla oficial? Esta investigación no responde por el usuario.

## Evidencia de implementación, no contrato de Anthropic

Repositorio inspeccionado: [OpenUsage](https://github.com/robinebers/openusage), HEAD `4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4` (descargado el 2026-09-23). Los siguientes enlaces fijan esa revisión:

- [ClaudeAuthStore.swift](https://github.com/robinebers/openusage/blob/4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4/Sources/OpenUsage/Providers/Claude/ClaudeAuthStore.swift): prioriza Keychain sobre archivo. Lee `claudeAiOauth.accessToken`; revisa `scopes`, en particular `user:profile`. Una lista ausente queda como desconocida, no como permiso denegado. El token de `setup-token` puede servir para inferencia y no para cuotas. Servicio de producción `Claude Code-credentials`; directorios personalizados incorporan un sufijo SHA-256 truncado. La fecha `expiresAt` se trata en milisegundos. Su lógica de renovación y persistencia no debe trasladarse al MVP de solo lectura.
- [ClaudeUsageClient.swift](https://github.com/robinebers/openusage/blob/4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4/Sources/OpenUsage/Providers/Claude/ClaudeUsageClient.swift): consulta `GET https://api.anthropic.com/api/oauth/usage` con Bearer y cabecera `anthropic-beta: oauth-2025-04-20`. Esta revisión agrega `cedar_ember=1` y un User-Agent que imita Claude CLI para obtener promociones de reinicios. **Eso no forma parte del alcance de UssyAi y no debe copiarse como requisito**; no se comprobó aquí qué cabeceras mínimas bastan. También usa `/api/oauth/profile` para identidad y plan actualizado, otra ruta interna opcional.
- [ClaudeUsageMapper.swift](https://github.com/robinebers/openusage/blob/4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4/Sources/OpenUsage/Providers/Claude/ClaudeUsageMapper.swift): lee ventanas opcionales `five_hour`, `seven_day`, `seven_day_sonnet`, cada una con `utilization` en porcentaje y `resets_at`. Ya contempla límites por modelo en `limits[]`, `kind: weekly_scoped`, `scope.model.display_name`, `percent` y `resets_at`. No hay garantía de un conjunto fijo de modelos. El mapper admite fechas ISO-8601 y epoch. Un objeto o porcentaje ausente no produce una barra a cero. Las métricas de gasto extra y promociones existen, pero exceden el MVP acordado.
- [ClaudeDesktopAuthStore.swift](https://github.com/robinebers/openusage/blob/4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4/Sources/OpenUsage/Providers/Claude/ClaudeDesktopAuthStore.swift) y [TokenCache](https://github.com/robinebers/openusage/blob/4ce788775e0cb3ec779d353b2ac9f9d7e8765bb4/Sources/OpenUsage/Providers/Claude/ClaudeDesktopAuthStore+TokenCache.swift): leen el caché cifrado `oauth:tokenCache` / `oauth:tokenCacheV2` de `~/Library/Application Support/Claude/config.json`, usando Keychain `Claude Safe Storage`, cuenta `Claude Key`. Hay dependencia de cookies para escoger organización. No extraen el refresh token para renovarlo. Detectan sesión vencida, formato inválido o permiso requerido; Desktop debe renovar su propia sesión. Esto demuestra complejidad real de un fallback Desktop, no una interfaz oficial.

## Propuesta técnica que habilitan los hechos (aún no decisión de producto)

1. Si se adopta la ruta interna, empezar con **Claude Code, OAuth de suscripción, solo lectura**. No usar API key como sustituto ni escanear conversaciones/logs, pues no permiten reconstruir fielmente la cuota agregada de todas las superficies.
2. Mostrar ventanas de cinco horas y semana cuando existan; modelos solo con datos explícitos. Porcentaje restante derivado `100 − usado` identificado como derivado; validar números finitos y rangos antes de renderizar. No inventar un reinicio para una ventana sin `resets_at`.
3. Leer la sesión oficial de nuevo tras un error de autenticación; nunca renovar, escribir ni revocar desde UssyAi. Pedir abrir Claude Code y renovar allí cuando corresponda. No atribuir todo 403 a vencimiento: puede faltar alcance o acceso al recurso.
4. Diferenciar sin credencial, acceso Keychain pendiente/denegado, credencial vencida/rechazada, alcance insuficiente, datos ausentes, respuesta incompatible, desconexión y limitación 429. Para 429 respetar `Retry-After`, mantener último dato etiquetado y evitar que refrescar manualmente ignore la espera; el mapper de OpenUsage implementa lectura de esa cabecera.
5. No mezclar caché tras cambiar sesión/cuenta. No usar metadatos locales del plan como fuente infalible: pueden quedar antiguos; el MVP puede omitir el nombre del plan y evitar otra consulta interna.

## Validaciones reales pendientes

- Confirmar con el usuario plan y superficie que realmente usa (Claude Code, Desktop o ambas), sin solicitar secretos.
- Resolver la pregunta de adopción de OAuth interno y el papel de Desktop; no asumir que la disponibilidad técnica resuelve las restricciones anteriores.
- Si se elige probar: validar lectura permitida por Keychain, forma actual del JSON y acceso con sesión real; confirmar alcance, expiración y que `CLAUDE_CONFIG_DIR` corresponda a la sesión deseada.
- Comparar porcentajes y reinicios con Settings > Usage en el mismo momento, incluyendo ventana no iniciada, campos null y límites por modelo. No se probó ninguno de estos casos en la cuenta real.
- Comprobar consulta sin parámetros de promociones ni suplantar el User-Agent del CLI; documentar cabeceras efectivamente necesarias.
- Simular 401, 403, 429, red caída, fecha inválida, cambio de cuenta y sesión que vence con la app abierta. Confirmar que no se escribe ninguna credencial ni se provocan prompts Keychain desde un temporizador.

El ticket de investigación queda resuelto por evidencia suficiente para decidir alcance; no equivale a integración validada ni a una decisión de incluirla.
