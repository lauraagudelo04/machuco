# Convenciones de desarrollo — referencia condensada

Fuente completa: `GUIA_MACHUCO.md`.

## Nombres

| Elemento | Convención | Ejemplo |
|---|---|---|
| Carpetas y archivos | `snake_case` | `reservation_repository.dart` |
| Clases, enums, extensiones | `UpperCamelCase` | `ReservationRepository` |
| Métodos, variables, parámetros | `lowerCamelCase` | `createReservation` |
| Booleanos | Condición explícita | `hasActiveReservation` |
| Métodos | Empiezan con verbo | `calculateReservationTotal` |

Nombres técnicos en inglés; textos visibles en español. Evita
`helpers.dart`, `manager`, `misc`, `new`, `final`, `old`, `copy`, `v2` sin
significado técnico concreto. Usa constantes/enums en vez de valores
mágicos (`const reservationTimeout = Duration(minutes: 10);`).

Prefiere enums sobre booleanos para variantes:

```dart
enum AppButtonVariant { primary, secondary, destructive }
```

## Construcción de widgets

- `const` en widgets/valores inmutables; `final` en propiedades.
- Divide un widget cuando se reutilice, tenga comportamiento propio o sea
  difícil de leer/probar — no por reducir líneas de un `Row`/`Column`.
- `build` debe ser declarativo: nunca consultas externas, procesamiento
  pesado, escrituras ni efectos secundarios ahí dentro.
- `ListView.builder`/slivers para listas extensas; keys estables en listas
  y animaciones.

## Asincronía, nulabilidad y rendimiento

- Controla carga, éxito y error en toda operación asíncrona.
- Después de un `await`, comprueba `mounted` antes de usar el contexto:

```dart
final reservation = await repository.createReservation(request);
if (!context.mounted) return;
Navigator.of(context).pop(reservation);
```

- Cancela suscripciones y libera controladores en `dispose`.
- Evita `!` sin comprobación previa; modela explícitamente la ausencia de
  datos. No optimices sin medir con las herramientas de perfilado.

## Estados, errores y validación

Toda operación con datos contempla: inicial, carga, contenido, vacío,
error, resultado de la acción. Nunca `catch` vacíos: registra sin datos
sensibles, da mensajes comprensibles, diferencia conexión/validación/
permisos/operación, ofrece reintento. La validación del cliente **nunca**
sustituye la del backend.

## Seguridad y privacidad

- Nunca secretos, credenciales, tokens, URLs privadas ni datos bancarios en
  el repositorio o los logs.
- Toda entrada externa se trata como no confiable.
- Autenticación y autorización por rol se validan en el servidor; ocultar
  un control en la UI no es autorización.
- No exponer reservas ni detalles de pagos en vistas previas o
  notificaciones sin autenticación.

## Dependencias

Se incorpora una dependencia solo si resuelve una necesidad real y
documentada, evaluando mantenimiento, licencia, vulnerabilidades,
compatibilidad Android/iOS y si Flutter ya resuelve el caso. Nunca dos
paquetes para el mismo propósito (estado, red, navegación, skeletons).

## Git y commits

Conventional Commits: `feat:`, `fix:`, `refactor:`, `style:`, `test:`,
`docs:`, `chore:`. Ramas descriptivas (`feature/motel-list`,
`fix/reservation-date-validation`) — nunca `cambios`, `prueba`, `final`,
`version2` o nombres personales.

## Calidad, antes de integrar

```bash
flutter pub get
dart format .
flutter analyze
flutter test
```

No integrar errores de análisis, imports sin uso, pruebas fallidas,
credenciales o dependencias sin uso.
