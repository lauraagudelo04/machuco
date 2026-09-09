---
name: token-economy
description: Reglas de ahorro de contexto/tokens que deben seguir todos los agentes de MACHUCO (arquitectura, frontend, backend, qa, health-reviewer) al explorar código, leer documentación o delegar trabajo. Úsalo siempre que vayas a leer archivos grandes, ejecutar comandos con salida extensa, coordinar varios agentes, o decidir cuánto contexto cargar.
---

# Economía de contexto en MACHUCO

Con 17 ramas activas y documentos de referencia largos
(`README_DISENO_FLUTTER.md` es el más pesado), seguir estas reglas evita
gastar tokens en información que no se va a usar.

## Reglas

1. **Busca antes de leer completo.** Si solo necesitas confirmar un dato
   puntual (un token de color, una responsabilidad de carpeta), usa
   `grep`/una búsqueda dirigida en vez de abrir el archivo entero.
2. **Prefiere las versiones `reference/` condensadas** de `project-context`
   sobre los README completos del repositorio. Solo abre el README
   completo si el `reference/` no resuelve la duda, y dilo explícitamente.
3. **Aísla la salida extensa.** Comandos como `flutter test`,
   `flutter analyze` o `git log` completos pueden generar mucho texto:
   delega esa ejecución a un subagente cuando sea posible, para que el
   detalle se quede en su contexto aislado y a la conversación principal
   solo vuelva el resumen (fallas, archivo, línea — no el log completo).
4. **Nunca cargues los 17 archivos de `contexts/people/`.** Solo el de la
   rama activa (vía `feature-context`), y solo la sección puntual de otra
   persona si hay una dependencia declarada.
5. **No releas lo ya resumido en esta sesión.** Si ya se exploró y
   resumió una carpeta o archivo, reutiliza ese resumen en vez de volver a
   abrir el archivo.
6. **Registra decisiones estables, no las vuelvas a derivar.** Si el
   agente tiene memoria persistente (`memory: project`), anota ahí
   convenciones o patrones ya acordados para no reconstruirlos cada sesión.
7. **Usa el modelo más económico que resuelva la tarea.** Chequeos
   mecánicos de checklist (health-reviewer en revisiones rutinarias) no
   necesitan el mismo modelo que una decisión de arquitectura o una
   implementación de UI compleja.
8. **Descripciones de agentes cortas.** Si editas o creas un agente nuevo
   en `.claude/agents/`, mantén su `description` breve y mueve el detalle
   al cuerpo del prompt, que solo se carga cuando ese agente se activa.
