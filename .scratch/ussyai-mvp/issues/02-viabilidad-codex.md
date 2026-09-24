# Determinar qué cuotas de Codex pueden consultarse en lectura

Type: research
Label: wayfinder:research
Status: resolved
Assignee: research_codex
Parent: ../map.md
Blocked by: none

## Question

¿Qué fuentes de sesión y métricas de Codex permiten una integración de solo lectura, qué estabilidad y restricciones tienen, y qué quedaría por comprobar con la cuenta real? Verificar archivos o Keychain, CODEX_HOME, OAuth frente a API key, identificación de ventanas, planes y errores con fuentes primarias actuales. No leer credenciales reales ni renovar tokens. Separar APIs documentadas de rutas internas.

## Context pointer

Rama: `research/ussyai-codex`. Worktree: `/tmp/ussyai-research-codex`.

## Answer

Investigación resuelta el 23 de septiembre de 2026: consulta viable condicionada mediante ruta interna; el app-server documentado puede renovar tokens y no asegura lectura pura. El almacenamiento y las ventanas son variables; API key no equivale a cuota ChatGPT. Falta validar cuenta real. Véase [Codex: viabilidad de cuotas de suscripción en UssyAi](../research/codex.md). Copia de trabajo idéntica en `/tmp/ussyai-research-codex/codex.md`, rama huérfana `research/ussyai-codex`, sin commits.
