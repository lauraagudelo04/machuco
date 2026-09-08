---
name: feature-context
description: Localiza y carga el contexto Gherkin específico de la persona/rama actual de MACHUCO (qué funcionalidad está construyendo, de qué depende, qué está fuera de alcance). Úsalo al iniciar cualquier tarea de desarrollo, antes de escribir o revisar código, para trabajar con el alcance correcto y no mezclarlo con el de otras 16 personas.
---

# Contexto por persona (Gherkin)

Cada una de las 17 ramas del proyecto tiene su propio archivo en
`contexts/people/<rama>.feature.md`, con su funcionalidad asignada escrita
en Gherkin más su alcance técnico.

## Pasos

1. Obtén la rama activa: `git branch --show-current`.
2. Busca `contexts/people/<rama>.feature.md` (el nombre de archivo debe
   coincidir con el nombre de la rama; si no coincide exactamente, busca
   por aproximación y confírmalo con la persona antes de asumir).
3. Carga **solo ese archivo**. No cargues los `.feature.md` de las demás
   16 personas — ni para "tener contexto general", eso ya lo da la skill
   `project-context`.
4. Si el archivo no existe, no inventes el alcance: pide a la persona que
   lo cree a partir de `reference/template.feature.md` antes de continuar,
   o pídele que te dicte el `Feature`/`Scenario` para crearlo tú.
5. Si la tarea depende explícitamente de la funcionalidad de otra persona
   (el propio archivo lo declara en "Depende de"), carga únicamente esa
   dependencia puntual — no el archivo completo de esa otra persona salvo
   que sea imprescindible.

## Qué hacer con el contenido

- Los `Scenario` son la base para entender qué se debe construir y, más
  adelante, qué debe probar el agente `qa`.
- La sección "Alcance técnico" dice en qué carpetas trabajar y qué queda
  fuera — respétala; si vas a salirte de ella, dilo explícitamente y por qué.
- Si el archivo contradice `project-context` (por ejemplo, propone fijar un
  backend), prioriza `project-context`/`CLAUDE.md` y señala la
  contradicción a la persona.
