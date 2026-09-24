# Codex: viabilidad de cuotas de suscripción en UssyAi

Investigación: 23 de septiembre de 2026. Código oficial `openai/codex`, revisión `7dae8c53d97e61cd774e4d6bcca5243c29ca615c` (HEAD consultado, no garantiza corresponder al binario instalado). Documentación oficial consultada en la misma fecha. Borrador tratado como hipótesis. No se leyeron sesiones, credenciales ni variables sensibles de la Mac; no se realizaron consultas autenticadas.

## Resultado para el MVP

**Viable de forma condicionada** para una sesión ChatGPT compatible: el cliente oficial contiene un GET de cuotas y modelos con porcentaje usado, duración y reinicio. Esto prueba que existe el mecanismo, no que la cuenta real de esta Mac pueda usarlo desde UssyAi. Conviene conservar el adaptador aislado y admitir indisponibilidad. La ruta HTTP es interna; no se encontró un contrato público estable de REST para terceros. Existe también una operación documentada del app-server, pero invocarla con autenticación administrada puede renovar credenciales, por lo que no satisface automáticamente la promesa de solo lectura. [GET oficial](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/backend-client/src/client/rate_limit_resets.rs#L69), [procesador app-server](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/app-server/src/request_processors/account_processor.rs#L1115).

## Hechos comprobados

### Sesión y almacenamiento

La documentación distingue `file`, `keyring`, `auto` y `ephemeral`: archivo `auth.json` dentro de `CODEX_HOME` (por defecto `~/.codex`), almacén del sistema, selección automática con respaldo a archivo, o memoria del proceso. CLI y extensión comparten caché. No debe suponerse que la app gráfica hereda las variables del shell. Ese último punto es una precaución de diseño, no una comprobación de la configuración real. [Autenticación oficial](https://learn.chatgpt.com/docs/auth#credential-storage).

El código de `AuthDotJson` contempla `auth_mode`, `OPENAI_API_KEY`, `tokens`, `last_refresh` y otros modos. `TokenData` incluye access token, refresh token, id token e identificador opcional de cuenta. UssyAi necesitaría solo el material para consultar, jamás el refresh token para renovar. No se debe elegir arbitrariamente otra cuenta cuando cambie la sesión. [Formato de autenticación](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/login/src/auth/storage.rs#L39), [tokens](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/login/src/token_data.rs#L9).

**Keychain tiene más de una variante en esta revisión.** El backend directo usa servicio `Codex Auth` y una clave `cli|` seguida de 16 caracteres hexadecimales del SHA-256 del path canónico de `CODEX_HOME`. También existe backend `Secrets`, con almacenamiento cifrado `codex_auth.age` y soporte de Keychain. Por tanto, el supuesto «buscar un único item de Keychain» no cubre todas las instalaciones actuales. `auto` prioriza su backend de Keychain y permite fallback a archivo. La sesión efímera no ofrece caché persistente para otra app. [Almacenes](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/login/src/auth/storage.rs#L235), [backend cifrado](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/login/src/auth/storage.rs#L326), [selección](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/login/src/auth/storage.rs#L501), [archivo cifrado](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/secrets/src/local.rs#L42).

### Consulta y significado de las métricas

El cliente oficial normaliza hosts ChatGPT con `/backend-api`; la ruta de uso ChatGPT es `GET /wham/usage`, componiendo `https://chatgpt.com/backend-api/wham/usage`. Agrega autenticación y `ChatGPT-Account-Id` cuando hay identidad de cuenta. También contempla otro estilo `/api/codex/usage`; no conviene deducir que cualquier base URL del usuario pertenece a OpenAI. El MVP debería restringirse a destinos explícitos aceptados y declarar otros como incompatibles. [Base y cabeceras](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/backend-client/src/client.rs#L209), [rutas](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/backend-client/src/client/rate_limit_resets.rs#L123).

La operación pública del protocolo local `account/rateLimits/read` expone un snapshot compatible anterior y un mapa `rateLimitsByLimitId`. `usedPercent` significa porcentaje usado; `windowDurationMins` es duración; `resetsAt` es timestamp Unix en segundos. `limitName`, plan, créditos y ventanas pueden faltar. Este contrato documentado permite diseñar el modelo, aunque se elija HTTP directo. [App-server oficial](https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt).

En HTTP, el mapeo oficial lee `used_percent`, `limit_window_seconds` y `reset_at`, y conserva ventanas ausentes como ausencia. Además de ventanas principal/secundaria hay buckets adicionales y datos opcionales de créditos/control de gasto. No hay base para asumir siempre «principal = 5 horas, secundaria = semana» ni para combinar buckets. Mostrar 5 horas solo ante 18 000 segundos y semanal solo ante 604 800; otras duraciones requieren etiqueta derivada del dato. «Restante» = 100 − usado es inferencia de presentación para porcentajes válidos, no cantidad de mensajes ni tokens. Nunca convertir null en cero o inventar un reset. [Conversión](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/backend-client/src/client.rs#L660), [ventanas](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/backend-client/src/client.rs#L740), [buckets adicionales](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/backend-client/src/client/rate_limit_resets.rs#L34).

### OAuth frente a API key; solo lectura

El procesador exige autenticación que use el backend de Codex; rechaza ausencia de sesión y autenticación incompatible. Una API key de Platform no debe interpretarse como cuota de suscripción ChatGPT. Los modos nuevos de identidad encontrados en el código no deben tratarse automáticamente como OAuth convencional; su soporte ampliaría el MVP. [Validación del procesador](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/app-server/src/request_processors/account_processor.rs#L1115).

**Riesgo concreto del app-server:** `get_account_rate_limits_response` obtiene `auth_with_http_client_factory()`, que llama a `auth()`. Para autenticación ChatGPT administrada, esta última puede ejecutar `refresh_token()` si considera necesaria una renovación proactiva. Es una posibilidad condicionada por el estado de sesión, no una escritura garantizada en cada lectura. No se auditó que todo el arranque de app-server carezca de otros efectos. Por ello, no recomendar lanzarlo como simple lector bajo el requisito actual. [Cadena de autenticación](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/login/src/auth/manager.rs#L2389).

El GET directo evita que UssyAi implemente esa renovación; debe leer de nuevo la sesión oficial en el siguiente intento. No se deben consumir créditos de reinicio, enviar avisos a dueños del workspace ni activar opciones reservadas para clientes capaces de aplicar Reserve. El código distingue explícitamente al lector pasivo. [Lectura y operaciones separadas](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/backend-client/src/client/rate_limit_resets.rs#L23).

## Política de fallos propuesta, no contrato remoto

- Falta de sesión o almacén inaccesible: distinguir ausencia de autenticación de permiso/almacenamiento incompatible; no buscar secretos indiscriminadamente.
- API key u otro modo no soportado: «Esta sesión no ofrece cuotas de suscripción».
- 401: solicitar actualizar sesión desde Codex; sin refresh automático. 403 también puede indicar restricción del servicio/workspace, no prueba suficiente de token vencido.
- 429: backoff y respetar Retry-After cuando exista; 5xx/red: reintento espaciado. No se confirmó frecuencia autorizada del endpoint interno: cinco minutos sigue siendo hipótesis del borrador.
- Respuesta incompatible o sin ventanas: datos no disponibles, jamás 0 %. Conservar último dato válido marcado desactualizado únicamente si corresponde a la misma cuenta.

Estas son decisiones recomendadas de UssyAi. El cliente oficial maneja errores de transporte/decodificación y el app-server convierte el fallo de consulta o ausencia de snapshots en error, pero no documenta todos los códigos de negocio de WHAM como contrato para terceros. [Procesador](https://github.com/openai/codex/blob/7dae8c53d97e61cd774e4d6bcca5243c29ca615c/codex-rs/app-server/src/request_processors/account_processor.rs#L1155).

## Validación pendiente y siguiente decisión

La investigación documental queda resuelta; la compatibilidad de la cuenta está pendiente. Una comprobación acotada deberá identificar versión instalada, modo de login y almacén efectivo sin exponer valores; comparar ventanas y reinicios con el indicador oficial; probar lectura de Keychain con la firma/permisos reales de UssyAi; verificar cambio de cuenta y expiración; comprobar que no se modificaron credenciales ni se contactaron destinos adicionales. No hay prueba autenticada realizada ni garantía de acceso a Keychain desde una app nueva.

Preguntas ya precisas para el mapa:

1. ¿Adoptamos el GET interno de solo lectura para sesiones OAuth compatibles, aceptando que el adaptador pueda quedar indisponible tras cambios del proveedor?
2. ¿Limitamos el primer lector a los almacenes que tenga esta Mac y declaramos efímero/cifrado/modos nuevos no compatibles hasta validarlos, o se requiere cobertura de todos desde el MVP?
3. ¿Qué buckets y duraciones reales presenta esta cuenta, y cuáles caben en la tarjeta sin mezclar cuota con créditos monetarios?

Recomendación: resolver primero la política común de integraciones internas; después validar la cuenta y almacén reales, sin convertir esta investigación en implementación.
