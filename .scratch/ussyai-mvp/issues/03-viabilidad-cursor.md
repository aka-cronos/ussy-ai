# Determinar qué cuotas de Cursor pueden consultarse en lectura

Type: research
Label: wayfinder:research
Status: resolved
Assignee: research_cursor
Parent: ../map.md
Blocked by: none

## Question

¿Qué fuentes de sesión y métricas de Cursor permiten una integración de solo lectura, qué estabilidad y restricciones tienen, y qué quedaría por comprobar con la cuenta real? Verificar fuentes locales, RPC y alternativas de consulta, diferencias de planes y ciclo de facturación. Aclarar cuándo hay un denominador válido para porcentaje y cuándo solo datos monetarios o conteos. No leer credenciales reales ni renovar tokens; distinguir código de terceros de contratos oficiales.

## Context pointer

Rama `research/ussyai-cursor`; worktree `/tmp/ussyai-research-cursor`.

## Answer

Investigación documental resuelta el 2026-09-23. Integración de solo lectura plausible mediante sesión local, RPC y respaldo REST combinado; sin contrato público personal encontrado ni validación con cuenta real. Hay dos bolsas mensuales y variantes por plan; el porcentaje requiere dato explícito o denominador comparable, nunca precio nominal. Mantener renovación y escritura de credenciales excluidas.

[Informe de viabilidad de Cursor](../research/cursor.md) contiene fuentes fijadas, limitaciones y preguntas para las siguientes decisiones.
