# Agentes, skills y contextos de Claude para MACHUCO

Este documento explica cómo instalar, usar y mantener el paquete de
agentes, skills y contextos por persona diseñado para que Claude Code
ayude a las 17 personas del equipo a desarrollar MACHUCO sin perder
tiempo re-explicando el proyecto en cada sesión, y sin gastar tokens de
más leyendo documentación que no aplica a la tarea del momento.

No reemplaza `README.md`, `GUIA_MACHUCO.md` ni `README_DISENO_FLUTTER.md`
— sigue siendo la fuente de verdad del producto y del diseño. Este paquete
es la capa que le enseña a Claude a **usar** esa documentación de forma
eficiente.

## 1. Qué contiene el paquete

```
CLAUDE.md                                   # contexto general, siempre cargado
.claude/
├── agents/
│   ├── arquitectura.md
│   ├── frontend.md
│   ├── backend.md
│   ├── qa.md
│   └── health-reviewer.md
└── skills/
    ├── project-context/
    │   ├── SKILL.md
    │   └── reference/
    │       ├── architecture.md
    │       ├── design-tokens.md
    │       ├── dev-guidelines.md
    │       └── health-checklist.md
    ├── feature-context/
    │   ├── SKILL.md
    │   └── reference/template.feature.md
    └── token-economy/
        └── SKILL.md
contexts/
└── people/
    ├── README.md
    └── ejemplo-reserva-habitacion.feature.md   # ejemplo, no una rama real
```

| Pieza | Qué es | Cuándo se carga |
|---|---|---|
| `CLAUDE.md` | Reglas no negociables del proyecto | Siempre, al iniciar cualquier sesión |
| `.claude/agents/*.md` | 5 subagentes especializados, compartidos por las 17 ramas | Cuando se delega una tarea a ese rol |
| `.claude/skills/*` | Conocimiento del proyecto en capas (resumen corto + detalle bajo demanda) | Solo si la tarea lo requiere |
| `contexts/people/*.feature.md` | Un archivo por persona/rama con su funcionalidad en Gherkin | Solo el de la rama activa |

## 2. Requisitos

- Trabajar con **Claude Code** (CLI, VS Code, JetBrains o la app de
  escritorio) apuntando a este repositorio. Los agentes y skills son
  específicos de Claude Code; no aplican si alguien usa otra herramienta.
- El repositorio debe estar inicializado en Git y cada persona debe estar
  parada en su propia rama (el sistema identifica el contexto por el
  nombre de la rama).

## 3. Instalación (una sola vez, por quien lidere esto)

1. Descomprime el paquete en la **raíz del repositorio**, de forma que
   `.claude/` y `contexts/` queden al mismo nivel que `lib/` y `pubspec.yaml`.
   `.claude/` es una carpeta oculta: verifica que tu explorador de
   archivos o `git status` la muestre antes de confirmar que quedó bien.
2. Revisa `contexts/people/ejemplo-reserva-habitacion.feature.md`: es solo
   una referencia. Bórralo cuando el equipo ya tenga sus propios archivos,
   o déjalo — no interfiere porque ninguna rama real se llama así.
3. Haz commit de todo:
   ```bash
   git add CLAUDE.md .claude contexts
   git commit -m "chore: agregar agentes, skills y contexto por persona para Claude Code"
   git push
   ```
4. Que cada persona haga `git pull`/merge de esto hacia su propia rama
   antes de seguir con el paso 4 de la sección siguiente.

No hace falta ningún script de instalación: todo es Markdown/YAML que
Claude Code detecta automáticamente al abrir el proyecto.

## 4. Primer uso — onboarding de cada persona (17 veces, una por rama)

1. Párate en tu rama de trabajo: `git checkout <tu-rama>`.
2. Copia la plantilla y complétala con tu funcionalidad real:
   ```bash
   cp .claude/skills/feature-context/reference/template.feature.md \
      contexts/people/<tu-rama-exacta>.feature.md
   ```
   El nombre del archivo **debe coincidir exactamente** con el nombre de
   tu rama — así los agentes lo encuentran solos.
3. Completa el archivo: rol de usuario, `Feature`/`Scenario` en Gherkin de
   lo que vas a construir, y la sección "Alcance técnico" (carpetas donde
   trabajas, dependencias con otras personas, qué queda fuera).
4. Haz commit solo de tu archivo:
   ```bash
   git add contexts/people/<tu-rama-exacta>.feature.md
   git commit -m "docs: agregar contexto de <tu-funcionalidad>"
   ```
5. Abre Claude Code en el repo y pide, por ejemplo:
   > "Usa el agente frontend para construir la pantalla que describí en mi
   > contexto"

   El agente invoca `feature-context`, lee tu archivo (y solo el tuyo) y
   `project-context` para las convenciones, y empieza a trabajar dentro de
   las carpetas que le corresponden.

Si dos personas comparten una rama base o trabajan en la misma rama en
distintos momentos, basta con que el archivo `.feature.md` se actualice
para reflejar el alcance vigente.

## 5. Cómo invocar cada agente

Los 5 agentes son compartidos: no hay que crear uno por persona. Se
invocan por nombre, igual para cualquier rama:

```text
Usa el agente arquitectura para revisar si esta carpeta nueva tiene sentido
Usa el agente frontend para construir la pantalla de detalle de motel
Usa el agente backend para modelar el repositorio de reservas
Usa el agente qa para escribir pruebas de la funcionalidad que acabo de hacer
Usa el agente health-reviewer para revisar si esta rama está lista para PR
```

También puedes @-mencionarlos escribiendo `@` y eligiendo el agente desde
el menú, o dejar que Claude decida solo cuál usar según la tarea (cada
agente tiene una `description` pensada para que la delegación automática
funcione).

| Agente | Úsalo para | No lo uses para |
|---|---|---|
| `arquitectura` | Revisar estructura, dependencias nuevas, decisiones prematuras, componentes duplicados entre ramas | Escribir código de una pantalla |
| `frontend` | Vistas, widgets, navegación, temas, accesibilidad | Modelos de datos o reglas de negocio |
| `backend` | Modelos, controllers, repositorios, servicios | Estilos o layout |
| `qa` | Pruebas unitarias/widget/golden/integración, `flutter test`/`analyze` | Implementar la funcionalidad en sí |
| `health-reviewer` | Chequeo final antes de abrir un PR o fusionar a la rama principal | Escribir o corregir código (es de solo lectura) |

## 6. Cómo funciona el ahorro de tokens (para que confíes en el diseño)

- `CLAUDE.md` se mantiene corto (reglas, no documentación completa), así
  que cada sesión arranca liviana.
- `project-context` no carga `README_DISENO_FLUTTER.md` completo (que
  incluye tablas HTML de colores): usa `reference/design-tokens.md`, una
  versión en texto plano con los mismos valores, mucho más liviana.
- `feature-context` asegura que nunca se carguen los 17 archivos de
  `contexts/people/`, solo el de la rama activa.
- `token-economy` recuerda a todos los agentes delegar salidas extensas
  (logs de `flutter test`, `git log`) a un subagente para que el detalle no
  llene la conversación principal, y usar el modelo más económico posible.
- Los 5 agentes son compartidos en vez de 17 (uno por persona), lo que
  evita agotar el presupuesto combinado de descripciones de agentes.

No tienes que hacer nada activamente para lograr esto: ya está en cómo
están escritos los archivos. Lo único que puede romperlo es que alguien
edite `CLAUDE.md` o un `SKILL.md` y vuelva a pegar ahí un documento
completo — evita esa tentación y, si hace falta más detalle, agrégalo
como un nuevo archivo en `reference/`, no en el archivo principal.

## 7. Plan de implementación sugerido (rollout)

1. **Fase 0 — Fundación** (ya hecha con este paquete): agentes, skills y
   plantilla listos, revisados por quien lidera arquitectura.
2. **Fase 1 — Piloto**: 2–3 personas siguen la sección 4, prueban los 5
   agentes en tareas reales y reportan si alguna `description` de agente o
   algún `reference/*.md` necesita ajuste.
3. **Fase 2 — Rollout completo**: las 17 personas crean su
   `contexts/people/<rama>.feature.md` siguiendo la sección 4. Como cada
   quien toca solo su propio archivo, el riesgo de conflictos de merge es
   mínimo.
4. **Fase 3 — Uso normal**: cada persona invoca los agentes según la
   tabla de la sección 5; `health-reviewer` se corre siempre antes de abrir
   un PR contra la rama principal.
5. **Fase 4 — Mantenimiento**: cuando cambie algo en `README.md`,
   `GUIA_MACHUCO.md` o `README_DISENO_FLUTTER.md` (por ejemplo, se decide
   el backend o el gestor de estado), actualiza el `reference/*.md`
   correspondiente en `project-context` — no hace falta tocar los agentes.

## 8. Mantenimiento y extensión

- **Cambió un token de diseño o una convención**: edita el archivo
  correspondiente en `.claude/skills/project-context/reference/`. Los
  agentes lo verán la próxima vez que invoquen la skill.
- **Se tomó una decisión pendiente** (backend, estado, pagos, etc.):
  actualízala en `README.md` y agrega el resumen accionable en
  `reference/architecture.md` o `reference/dev-guidelines.md` según
  corresponda.
- **Necesitas un agente nuevo** (por ejemplo, un agente de "Notificaciones"
  si crece lo suficiente): créalo en `.claude/agents/` con el mismo patrón
  (frontmatter con `name`, `description` corta, `tools` mínimos necesarios,
  `skills` con `project-context`/`feature-context`/`token-economy`).
- **Necesitas una skill nueva**: solo agrégala si un tema se repite mucho
  y no cabe bien en las 3 existentes. Mantén el `SKILL.md` corto y mueve el
  detalle a `reference/`, igual que las demás.
- Todo esto se hace editando o creando archivos Markdown/YAML — nunca hace
  falta escribir ni mantener scripts para que el sistema funcione.

## 9. Problemas comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| Un agente nuevo no aparece | La sesión de Claude Code ya estaba abierta cuando se creó `.claude/agents/` por primera vez | Reinicia la sesión de Claude Code |
| El agente no encuentra mi contexto | El nombre del archivo no coincide exactamente con el de la rama | Renombra `contexts/people/<archivo>.feature.md` para que coincida con `git branch --show-current` |
| Un agente parece "no saber" una convención de diseño/código | La convención cambió pero no se actualizó el `reference/*.md` | Actualiza el `reference/*.md` correspondiente en `project-context` |
| Dos personas construyeron el mismo componente | No se corrió el agente `arquitectura` antes de duplicar | Usa `arquitectura` para revisar antes de crear componentes nuevos en `widgets/` o `design_system/` |
| El agente `health-reviewer` bloquea el PR | Encontró algo de la checklist en rojo | Revisa el veredicto y los puntos ⚠️/❌ que reporta antes de insistir en el merge |
