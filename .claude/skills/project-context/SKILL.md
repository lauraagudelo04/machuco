---
name: project-context
description: Contexto general del proyecto MACHUCO (producto, arquitectura provisional de lib/, sistema de diseño, convenciones de código, checklist de salud). Úsalo antes de tocar código para entender qué hace la app, cómo está organizada, o qué tokens/convenciones aplican — en vez de leer README.md, GUIA_MACHUCO.md o README_DISENO_FLUTTER.md completos.
---

# MACHUCO — contexto general

App Flutter (Android/iOS) para consultar, reservar y administrar moteles.

- **Cliente**: consulta moteles/habitaciones, reserva, paga, ve PQRS,
  facturas e historial de pagos.
- **Propietario**: administra sus moteles, habitaciones, clientes, reservas,
  pagos, facturas, recibos de caja y notificaciones de cancelación.
- **Administrador**: supervisa propietarios, moteles, finanzas, reservas,
  PQRS, servicios y habitaciones de toda la plataforma.

Tecnologías fijas: Flutter, Dart, Android Studio, Git. **Todavía no están
decididos**: backend, base de datos, autenticación, pasarela de pagos,
almacenamiento de imágenes, gestor de estado, navegación definitiva ni
plataforma de despliegue — no los fijes por tu cuenta dentro de una rama.

## Cuándo profundizar (no cargues estos archivos si no los necesitas)

| Necesitas... | Consulta |
|---|---|
| Estructura de `lib/`, responsabilidad de cada carpeta, dónde va un componente nuevo | `reference/architecture.md` |
| Colores, tipografía, espaciado, radios, movimiento, iconografía | `reference/design-tokens.md` |
| Nombres, async/nulabilidad, seguridad, gestión de dependencias | `reference/dev-guidelines.md` |
| Checklist de PR / criterios de aceptación visual | `reference/health-checklist.md` |

Estos archivos son versiones condensadas de `README.md`, `GUIA_MACHUCO.md`
y `README_DISENO_FLUTTER.md`. Úsalos primero. Solo abre los documentos
completos del repositorio si necesitas un detalle que no está aquí (por
ejemplo, la justificación completa de una decisión, no el valor del token).
