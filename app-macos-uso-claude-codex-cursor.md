# App personal de macOS para consultar uso de Claude, Codex y Cursor

## Objetivo

Construir una app nativa que viva en la barra de menús de macOS y muestre, en un solo panel, el uso disponible de **Claude, Codex y Cursor**. Debe aprovechar las sesiones que ya existen en las apps oficiales, sin pedir contraseñas ni crear otra cuenta. Es una herramienta para una sola persona y una sola Mac.

**Resultado mínimo:** tres tarjetas con porcentaje usado y restante, fecha u hora de reinicio cuando el proveedor la entregue, momento de la última actualización y un estado claro cuando falten credenciales o falle una consulta. Los proveedores tienen límites distintos; la interfaz no debe inventar un porcentaje único combinado.

## Alcance

| Incluir | Dejar fuera |
|---|---|
| Barra de menús y panel compacto | Telemetría, analítica y reportes automáticos de fallos |
| Claude, Codex y Cursor | Otros proveedores y cuentas múltiples |
| Actualización al abrir, periódica y manual | iCloud, sincronización y API HTTP local |
| Credenciales existentes y consultas a cada proveedor | Login propio, servidor, base de datos remota |
| Estados de error y datos desactualizados | Historial de tokens/costos, precios, widgets y autoactualización |
| Preferencia local sencilla para frecuencia o mostrar porcentaje restante | Onboarding complejo y opciones extensas de personalización |

No incluir SDK de analítica ni peticiones a dominios ajenos a los tres proveedores. La app solo necesita enviar a cada proveedor las solicitudes necesarias para consultar sus límites. OpenUsage **sí** documenta pings de actividad y reportes de fallos obligatorios en su versión actual; por eso no conviene asumir que desactivar una opción en esa app equivale a «sin telemetría». [Fuente: privacidad de OpenUsage](https://github.com/robinebers/openusage/blob/main/docs/privacy.md).

## Arquitectura propuesta

Usar **Swift + SwiftUI** para el panel y **AppKit** para el ícono de la barra de menús (`NSStatusItem`). Para esta app personal basta un proyecto pequeño en Xcode o Swift Package Manager. Elegir como punto de partida macOS 15 o posterior, que coincide con el mínimo de la versión actual de OpenUsage; ajustar el objetivo a la Mac real antes de implementar. [Fuente: README y arquitectura de OpenUsage](https://github.com/robinebers/openusage).

```text
MenuBarApp
  ├─ StatusItem + panel SwiftUI
  ├─ UsageStore: estado observable, última lectura y errores
  ├─ RefreshCoordinator: inicio, temporizador, actualización manual y backoff
  └─ Providers
       ├─ ClaudeProvider: credencial → API → métricas
       ├─ CodexProvider: credencial → API → métricas
       └─ CursorProvider: credencial → API → métricas
```

Cada proveedor implementa una interfaz pequeña como `fetchUsage() async throws -> ProviderSnapshot`. El modelo normalizado debe conservar **proveedor, nombre de la métrica, porcentaje usado opcional, valor restante opcional, unidad, fecha de reinicio opcional, fecha de consulta y estado**. Mantener el dato original cuando sea útil para no confundir «usado» con «restante». Una métrica ausente debe mostrarse como **No disponible**, nunca como cero. La separación entre lectura de credenciales, cliente de red y mapeo está inspirada en la arquitectura de OpenUsage. [Fuente: arquitectura de OpenUsage](https://github.com/robinebers/openusage/blob/main/docs/architecture.md).

## Integraciones

Los mecanismos de abajo describen la implementación actual de OpenUsage, **no APIs públicas estables**. Antes de programar cada adaptador, revisar el código y la documentación vigentes del proveedor y probar con la sesión real del usuario.

| Proveedor | Sesión local | Consulta de uso | Métricas iniciales |
|---|---|---|---|
| **Claude** | Credencial de Claude Code en Keychain o `~/.claude/.credentials.json`; contemplar `CLAUDE_CONFIG_DIR`. Claude Desktop puede ser una alternativa de solo lectura. | OAuth de Anthropic; OpenUsage documenta `GET https://api.anthropic.com/api/oauth/usage`. | Ventana de 5 horas, semanal y límites por modelo solo si aparecen en la respuesta. |
| **Codex** | Autenticación del Codex CLI en `CODEX_HOME` o su ubicación predeterminada, con posible respaldo en Keychain. | OpenUsage documenta `GET https://chatgpt.com/backend-api/wham/usage` con el token OAuth de Codex. | Ventana de 5 horas y semanal; clasificar por duración reportada, no por posición en el JSON. |
| **Cursor** | Sesión ya iniciada en la app Cursor; estado local y Keychain. | OpenUsage usa RPC en `api2.cursor.sh` y consultas de respaldo en `cursor.com/api/usage` y `cursor.com/api/usage-summary`. | Uso total del ciclo de facturación; separar otras métricas solo si la cuenta las devuelve. |

Fuentes: [Claude](https://github.com/robinebers/openusage/blob/main/docs/providers/claude.md), [Codex](https://github.com/robinebers/openusage/blob/main/docs/providers/codex.md), [Cursor](https://github.com/robinebers/openusage/blob/main/docs/providers/cursor.md).

**Autenticación y renovación.** Empezar leyendo credenciales existentes sin modificarlas. Si un token vence, mostrar «Abre/inicia sesión en Claude Code, Codex o Cursor y vuelve a actualizar». Esto permite una primera versión útil y evita romper las sesiones de las apps oficiales. Después, si la renovación automática resulta necesaria, implementarla **por proveedor**: una sola renovación ante 401/403, escritura atómica y con permisos de usuario, comprobación de que la cuenta y el archivo no cambiaron durante la operación y pruebas de concurrencia. Nunca renovar ni escribir el token de Claude Desktop: OpenUsage también trata esa sesión como solo lectura. Codex y Cursor requieren especial cuidado porque OpenUsage documenta rotación o persistencia de tokens. [Fuentes: Claude](https://github.com/robinebers/openusage/blob/main/docs/providers/claude.md), [Codex](https://github.com/robinebers/openusage/blob/main/docs/providers/codex.md), [Cursor](https://github.com/robinebers/openusage/blob/main/docs/providers/cursor.md).

**Limitación conocida.** Una configuración que use solo API key puede no exponer los límites de suscripción. No mezclar consumo de API con cuota de la suscripción. [Fuente: Codex](https://github.com/robinebers/openusage/blob/main/docs/providers/codex.md).

## Actualización e interfaz

- Consultar al abrir y después aproximadamente cada **5 minutos**, con botón **Actualizar**. Evitar consultas superpuestas al mismo proveedor y respetar respuestas de limitación de frecuencia con espera progresiva. OpenUsage usa una cadencia de 5 minutos como referencia, no como obligación. [Fuente: actualización de OpenUsage](https://github.com/robinebers/openusage/blob/main/docs/refreshing.md).
- Mostrar el último dato válido si una consulta falla, marcado como **desactualizado** y con la hora de la última lectura correcta. Nunca presentar un dato viejo como si fuera actual.
- En cada tarjeta, mostrar el nombre del proveedor, las métricas disponibles, porcentaje usado o restante según una preferencia simple, y cuenta regresiva hasta el reinicio solo cuando exista una fecha válida.
- Distinguir visualmente **sin sesión**, **sesión vencida**, **sin datos para este plan**, **sin conexión** y **error del proveedor**. No mostrar tokens, correos ni respuestas crudas en la interfaz o en logs.
- Mantener el estado en memoria en la primera versión. Si se añade caché en disco, guardar solo métricas normalizadas y la identidad de cuenta necesaria para evitar mostrar datos de otra sesión tras un cambio de cuenta; nunca guardar tokens en esa caché. [Fuente: caché de OpenUsage](https://github.com/robinebers/openusage/blob/main/docs/refreshing.md).

## Seguridad y privacidad

1. Leer solo las ubicaciones de autenticación necesarias. No copiar secretos a preferencias, archivos de diagnóstico, crash reports ni portapapeles.
2. Usar `URLSession` con HTTPS y destinos explícitos de Anthropic, ChatGPT/OpenAI y Cursor. No añadir PostHog, Sentry, servicios de precios, servidor local ni comprobación de actualizaciones.
3. No solicitar credenciales manualmente dentro de la app. La recuperación de sesión ocurre en la app oficial correspondiente.
4. Diseñar los errores para que los logs registren categorías y códigos, nunca cabeceras `Authorization`, cookies, tokens o cuerpos de respuesta.
5. Validar el comportamiento real con un monitor de red durante una sesión de prueba: solo deben aparecer solicitudes a los dominios necesarios para consultar o, si se incorpora, renovar las sesiones de esos proveedores.

## Orden de implementación para el otro agente

1. Crear la app de barra de menús y el panel con datos simulados. Definir `ProviderSnapshot` y estados vacíos/de error.
2. Implementar **Codex** y validar contra el indicador oficial de uso de la cuenta. Es la integración de referencia para el modelo normalizado.
3. Implementar **Claude** con Claude Code. Añadir Claude Desktop solo si es la sesión que usa esta Mac.
4. Implementar **Cursor**, probando con el plan real. Su estado local y sus rutas de consulta son la parte más frágil; aislarlas detrás del adaptador.
5. Añadir el coordinador de actualizaciones, manejo de errores, espera progresiva y, solo si hace falta, renovación de tokens.
6. Hacer una prueba manual de privacidad y una prueba de uso prolongado. Comparar porcentajes y reinicios con las interfaces oficiales; documentar cualquier métrica que el proveedor no entregue.

## Criterios de aceptación

- La app abre desde la barra de menús y presenta las tres tarjetas sin pedir un inicio de sesión adicional.
- Una cuenta ya iniciada muestra sus límites; una cuenta ausente muestra instrucciones concretas para iniciar sesión en la app oficial.
- Los porcentajes y fechas de reinicio coinciden con las fuentes oficiales en la misma ventana temporal, admitiendo diferencias por redondeo o retraso de actualización.
- Un error de red conserva y etiqueta el último dato válido; una métrica ausente no aparece como 0 %.
- El botón de actualización funciona y el temporizador no lanza consultas duplicadas.
- No hay telemetría, analítica, reportes de fallos, sincronización ni tráfico a servicios adicionales.
- La app no modifica credenciales en la primera versión; cualquier renovación automática posterior queda acotada y probada por proveedor.

## Nota para implementación

OpenUsage sirve como **referencia técnica** y tiene licencia MIT, pero esta app debe mantener un alcance mucho menor. Si se copia código suyo, conservar los avisos de licencia correspondientes y revisar qué dependencias o tráfico trae ese código. Las rutas internas y formatos de autenticación pueden cambiar sin aviso; conviene registrar la fecha de la versión de cada integración y mantener los adaptadores fáciles de sustituir. [Repositorio y licencia](https://github.com/robinebers/openusage).
