# MACHUCO — contexto para agentes

App móvil multiplataforma (Flutter, Android/iOS) para consultar, reservar y
administrar moteles. Tres roles: **Cliente**, **Propietario**, **Administrador
del sistema**. Detalle completo del producto en `README.md`.

El proyecto está en desarrollo activo, con 17 ramas (una por persona). Cada
rama tiene su propio archivo de contexto en `contexts/people/`.

## Reglas no negociables

- No fijar backend, base de datos, gestor de estado, pasarela de pagos ni
  almacenamiento sin una decisión documentada y acordada por el equipo (ver
  README.md → "Estado y decisiones pendientes"). No agregues dependencias
  para resolver esto por tu cuenta.
- Nunca hardcodear colores hexadecimales, radios o duraciones en una vista.
  Usar siempre los tokens del design system (ver skill `project-context`).
- Nombres técnicos (carpetas, archivos, clases, variables) en inglés; textos
  visibles en español. `snake_case` en archivos/carpetas, `UpperCamelCase`
  en clases/enums, `lowerCamelCase` en métodos/variables.
- No reorganizar sustancialmente la estructura provisional de `lib/` sin
  acuerdo del equipo (ver skill `project-context` → reference/architecture.md).
- La interfaz, la lógica de aplicación y el acceso a datos deben permanecer
  separados. Ninguna vista debe consultar una API, procesar pagos o persistir
  datos directamente.
- Validación de autenticación y autorización por rol siempre en el backend;
  ocultar un control en la UI no es autorización.

## Documentación fuente

No la dupliques ni la cargues completa por defecto: `README.md`,
`GUIA_MACHUCO.md` y `README_DISENO_FLUTTER.md` son la fuente de verdad, pero
son largas. Las skills de este repo ya traen versiones condensadas para el
trabajo diario; solo abre los README completos si la skill no resuelve la duda.

## Cómo debe trabajar cualquier agente

1. Invoca la skill **`feature-context`** para saber qué funcionalidad y
   alcance le corresponden a la rama activa. No trabajes sin esto.
2. Invoca la skill **`project-context`** cuando necesites arquitectura,
   convenciones de código o el sistema de diseño.
3. Sigue en todo momento las reglas de la skill **`token-economy`** al
   explorar código, leer documentación o delegar trabajo a subagentes.

## Agentes disponibles

`arquitectura`, `frontend`, `backend`, `qa`, `health-reviewer` — ver
`.claude/agents/`. Son compartidos por las 17 ramas; lo que cambia por
persona es el archivo en `contexts/people/`, no el agente.
