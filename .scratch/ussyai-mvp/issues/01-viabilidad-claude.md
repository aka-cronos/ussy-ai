# Determinar qué cuotas de Claude pueden consultarse en lectura

Type: research
Label: wayfinder:research
Status: resolved
Assignee: research_claude
Parent: ../map.md
Blocked by: none

## Question

¿Qué fuentes de sesión y métricas de Claude permiten una integración de solo lectura, qué estabilidad y restricciones tienen, y qué quedaría por comprobar con la cuenta real? Contrastar Claude Code y Desktop, vencimiento, planes, ventanas y campos ausentes con fuentes primarias actuales. No leer credenciales reales. Proponer un alcance viable sin convertir una interfaz interna en garantía pública.

Context pointer: branch `research/ussyai-claude`; worktree `/tmp/ussyai-research-claude`.

## Answer

Investigación completada el 2026-09-23: [Viabilidad de lectura de cuotas de Claude](../research/claude.md). Existe evidencia de una ruta OAuth interna con sesión Code; Desktop agrega formatos privados. Cuotas de cinco horas, semana y por modelo son opcionales. No se comprobó la cuenta real. La documentación oficial restringe reuso/intermediación de OAuth sin tratar explícitamente este monitor personal; el informe separa esa incertidumbre de la viabilidad técnica y propone una decisión posterior, sin tomarla por el usuario.
