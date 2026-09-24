# UssyAi

App de barra de menús para macOS que muestra de un vistazo las cuotas de suscripción de **Claude**, **Codex** y **Cursor**: cuánto has usado, cuánto te queda y cuándo se reinicia cada una.

> **Estado:** en diseño. El MVP está especificado en [#11](https://github.com/aka-cronos/ussy-ai/issues/11), pero aún no hay código de la app.

## Qué hace

- Un icono fijo en la barra de menús abre un panel con una tarjeta por proveedor.
- Cada cuota se muestra por separado (p. ej. «5 horas» y «Semanal»), con su barra, su reinicio en hora local y la hora de la última lectura. Nunca se combinan cuotas en un porcentaje único.
- Selector entre cuota usada y cuota restante.
- Si un proveedor falla, su tarjeta explica por qué (sin sesión, sesión vencida, sin conexión, respuesta incompatible…) y las demás siguen funcionando. Un dato ausente nunca se muestra como cero.

## Privacidad

- Reutiliza **en solo lectura** las sesiones que ya existen en Claude Code, Codex CLI y Cursor. No pide contraseñas, no inicia sesión, no renueva tokens y no escribe credenciales.
- Solo se conecta a `api.anthropic.com`, `chatgpt.com` y `api2.cursor.sh`. Sin telemetría ni servidor propio.
- Las cuotas viven solo en memoria; no se guardan en disco.

## Aviso

Las rutas que usa la app para consultar cuotas son **internas y no documentadas** por los proveedores. Pueden cambiar o dejar de funcionar sin aviso. UssyAi no está afiliada a Anthropic, OpenAI ni Anysphere.

## Requisitos (previstos)

- macOS 27, Apple Silicon.
- Xcode completo para compilar.
- Sesión iniciada en Claude Code, Codex CLI (modo ChatGPT) y/o Cursor.

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| `CONTEXT.md` | Vocabulario del dominio (cuota usada, reinicio, último dato válido…). |
| `docs/agents/` | Convenciones para agentes: issues, etiquetas de triaje, documentación de dominio. |

Las decisiones de diseño están en los [issues](https://github.com/aka-cronos/ussy-ai/issues?q=is%3Aissue) del mapa [#1](https://github.com/aka-cronos/ussy-ai/issues/1).

## Licencia

[MIT](LICENSE).
