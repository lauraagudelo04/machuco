# contexts/people/

Un archivo por persona/rama: `<nombre-exacto-de-la-rama>.feature.md`.

- La skill `feature-context` (`.claude/skills/feature-context/`) busca aquí
  automáticamente el archivo que coincide con `git branch --show-current`.
- La plantilla está en
  `.claude/skills/feature-context/reference/template.feature.md`.
- Ver `ejemplo-reserva-habitacion.feature.md` en esta misma carpeta para un
  caso ya completado, a modo de referencia.

Reglas:

- No dupliques aquí lo que ya está en `project-context` (arquitectura,
  tokens de diseño, convenciones) — solo lo específico de tu funcionalidad.
- Actualiza tu archivo si cambia el alcance de lo que estás construyendo;
  es la fuente que usan los 5 agentes para saber qué te corresponde.
- Cada persona es dueña de su propio archivo — evita editar el de otra
  persona salvo acuerdo explícito, para no generar conflictos de merge.
