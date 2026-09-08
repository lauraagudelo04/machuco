# Checklist de salud / PR — referencia condensada

Fuentes completas: `GUIA_MACHUCO.md` (proceso) y `README_DISENO_FLUTTER.md`
(criterios visuales, sección 18).

## Checklist mínima de PR

```text
[ ] El proyecto compila
[ ] flutter analyze no presenta errores
[ ] Las pruebas existentes pasan
[ ] Los componentes siguen la guía visual
[ ] No se incluyeron secretos
[ ] No se duplicaron componentes existentes
[ ] La navegación funciona correctamente
[ ] Se validaron carga, error y ausencia de datos
[ ] Funciona en diferentes tamaños de pantalla
[ ] Se revisó el acceso según el rol
```

## Criterios de aceptación visual

- Sin colores hexadecimales ni estilos globales duplicados en las vistas.
- Todas las pantallas usan los temas claro/oscuro globales, sin colores
  locales dependientes del brillo.
- Componentes esenciales tienen variantes loading/disabled/error cuando
  corresponde.
- Áreas táctiles ≥48×48px.
- El texto funciona al 200% sin perder acciones ni información.
- Ningún estado depende solo del color.
- Navegación inferior, sheets y contenido respetan safe areas.
- Carga, vacío, error, sin conexión y reintento están definidos.
- Imágenes con placeholder, fallback y relación de aspecto estable.
- `dart format`, `flutter analyze` y `flutter test` terminan sin errores.
- Se verificó al menos un dispositivo/simulador Android y uno iOS.

## Prioridad de pruebas (para QA y para decidir qué falta)

Login y acceso por rol → moteles/habitaciones → fecha/hora/disponibilidad
→ creación/cancelación de reservas → productos y servicios → cálculo de
valores → pagos → gestión del propietario.

## Señales de bloqueo (marcar como "No lista" en la revisión)

- Secretos, credenciales o URLs privadas en el diff.
- Autorización por rol resuelta solo en la interfaz.
- Backend, base de datos, pagos o gestor de estado fijados unilateralmente
  dentro de la rama sin decisión de equipo.
- Componentes visuales duplicados respecto a `widgets/` o
  `core/design_system/components/` ya existentes.
- `flutter analyze` o `flutter test` en rojo.
