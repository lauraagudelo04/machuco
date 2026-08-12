# Guía de buenas prácticas de MACHUCO

Normas de arquitectura, código, seguridad, dependencias, pruebas y colaboración para el desarrollo del proyecto.

Para comprender el producto, consulte [README.md](README.md). Para colores, tipografía, componentes, movimiento, accesibilidad y demás decisiones de interfaz, consulte [README_DISENO_FLUTTER.md](README_DISENO_FLUTTER.md).

## Índice

1. [Principios de desarrollo](#principios-de-desarrollo)
2. [Estructura provisional del proyecto](#estructura-provisional-del-proyecto)
3. [Convenciones de código](#convenciones-de-código)
4. [Construcción y responsabilidades](#construcción-y-responsabilidades)
5. [Estados, errores y validación](#estados-errores-y-validación)
6. [Asincronía, nulabilidad y rendimiento](#asincronía-nulabilidad-y-rendimiento)
7. [Seguridad y privacidad](#seguridad-y-privacidad)
8. [Gestión de dependencias](#gestión-de-dependencias)
9. [Calidad y pruebas](#calidad-y-pruebas)
10. [Git y pull requests](#git-y-pull-requests)

## Principios de desarrollo

- Cada archivo, clase, función y widget debe tener una responsabilidad principal.
- La interfaz, la lógica de aplicación y el acceso a datos deben permanecer separados.
- Se debe reutilizar código cuando exista una abstracción clara, sin fragmentar artificialmente la solución.
- Las decisiones pendientes no deben fijarse de forma unilateral mediante dependencias o estructuras difíciles de reemplazar.
- El código debe favorecer legibilidad, pruebas, seguridad y mantenimiento por encima de soluciones implícitas.

## Estructura provisional del proyecto

```text
lib/
├── widgets/
├── views/
├── models/
├── controllers/
├── routes/
├── service/
├── data/
├── repository/
├── utils/
└── main.dart
```

Esta estructura no representa todavía una arquitectura definitiva. No debe ampliarse o reorganizarse sustancialmente sin una decisión acordada por el equipo.

| Directorio | Responsabilidad |
| --- | --- |
| `widgets` | Componentes reutilizables. Un componente compartido debe responder a una reutilización real o formar parte del sistema visual. |
| `views` | Pantallas que presentan información, reciben interacciones, muestran estados y delegan la lógica. |
| `models` | Representaciones del dominio, como `Motel`, `Room`, `Reservation`, `AdditionalService`, `Product`, `Payment`, `Review`, `Subscription`, `PqrsRequest` y `User`. |
| `controllers` | Coordinación entre interfaz, servicios y datos según la arquitectura elegida; no deben concentrar toda la lógica. |
| `routes` | Rutas centralizadas, acceso por autenticación y rol, y separación de vistas de cliente y propietario. |
| `service` | Operaciones externas o procesos específicos, sin mezclar UI, navegación ni transformaciones no relacionadas. |
| `data` | Obtención, representación o almacenamiento de datos, sin asumir todavía una fuente concreta. |
| `repository` | Contratos que abstraen el origen de la información y evitan dependencias directas desde las vistas. |
| `utils` | Utilidades pequeñas y concretas, como formateadores, validadores o mapeadores. |
| `main.dart` | Inicialización de Flutter, configuración global, dependencias, tema y ejecución de la aplicación. |

Evite archivos genéricos como `helpers.dart`, `functions.dart`, `general.dart`, `varios.dart` o `utils2.dart`. Prefiera nombres como `date_formatter.dart`, `currency_formatter.dart`, `input_validators.dart` y `reservation_status_mapper.dart`.

## Convenciones de código

Los nombres técnicos —carpetas, archivos, clases, métodos y variables— deben escribirse en inglés. Los textos visibles pueden estar en español o gestionarse mediante la solución de internacionalización que se adopte.

| Elemento | Convención | Ejemplo |
| --- | --- | --- |
| Carpetas y archivos | `snake_case` | `reservation_repository.dart` |
| Clases, enums y extensiones | `UpperCamelCase` | `ReservationRepository` |
| Métodos, variables y parámetros | `lowerCamelCase` | `createReservation` |
| Booleanos | Condición explícita | `hasActiveReservation` |
| Métodos | Comenzar con un verbo | `calculateReservationTotal` |

Los nombres deben revelar la responsabilidad: `motel_detail_view.dart`, `reservation_card.dart`, `payment_service.dart` o `reservation_validator.dart`. No use sufijos ambiguos como `manager`, `helper`, `misc`, `new`, `final`, `old`, `copy` o `v2` sin significado técnico concreto.

Use constantes, enums o modelos descriptivos en vez de valores mágicos:

```dart
const reservationTimeout = Duration(minutes: 10);
const minimumGuestCount = 1;
```

Ordene los imports en grupos: bibliotecas de Dart, Flutter o terceros y archivos del proyecto. Elimine imports sin uso y evite rutas relativas profundas cuando exista una convención de imports de paquete.

## Construcción y responsabilidades

- Use `const` en widgets y valores inmutables, y `final` en propiedades siempre que sea posible.
- Cree nuevos estados en lugar de mutar de forma impredecible objetos o colecciones compartidas.
- Divida una pantalla cuando un bloque se reutilice, tenga comportamiento propio, sea difícil de leer o necesite pruebas independientes.
- No divida cada `Row` o `Column` únicamente para reducir líneas.
- Mantenga `build` declarativo: no debe ejecutar consultas externas, procesamiento pesado, escrituras, efectos secundarios ni transformaciones repetitivas.
- No permita que una vista consulte una API, procese pagos, aplique reglas de negocio, persista datos y controle toda la navegación a la vez.
- No duplique validaciones, formatos monetarios, mensajes, tratamiento de estados ni componentes. Los tokens y estilos visuales se centralizan conforme a la guía de diseño.
- Los comentarios deben explicar decisiones no evidentes, no repetir el código. Use documentación Dart en APIs públicas o lógica compleja.
- No conserve código comentado, datos de prueba sin identificar, duplicados ni archivos temporales en ramas principales; Git conserva el historial.

## Estados, errores y validación

Toda operación basada en datos debe contemplar estado inicial, carga, contenido, ausencia de datos, error y resultado de la acción. La presentación concreta de esos estados se define en la guía de diseño.

No oculte errores con bloques `catch` vacíos. Los errores deben registrarse sin información sensible, convertirse en mensajes comprensibles, diferenciar conexión, validación, permisos y operación, y ofrecer reintento cuando corresponda. No muestre mensajes técnicos directamente al usuario.

Valide antes de operar, según corresponda:

- Campos obligatorios, correo y teléfono.
- Cantidad de personas y productos.
- Fechas, horarios y disponibilidad.
- Valores monetarios.
- Términos y condiciones.
- Información requerida para pagos.

La validación del cliente no sustituye la validación ni la autorización del backend.

## Asincronía, nulabilidad y rendimiento

- Controle carga, éxito y error en toda operación asíncrona.
- Después de un `await`, compruebe `mounted` antes de usar el contexto de un widget.
- Cancele suscripciones y libere controladores en `dispose`.
- No inicie operaciones sin esperar su resultado salvo que la decisión esté justificada y sus errores estén controlados.
- Evite `!` sin una comprobación previa; modele explícitamente la ausencia de datos.
- Use constructores `const` y `ListView.builder` o slivers para colecciones extensas.
- Evite cálculos, conversiones y objetos repetitivos dentro de `build`.
- No optimice sin mediciones; use las herramientas de perfilado de Flutter cuando exista un problema real.

```dart
final reservation = await repository.createReservation(request);
if (!context.mounted) return;
Navigator.of(context).pop(reservation);
```

## Seguridad y privacidad

Por la naturaleza del producto, la privacidad forma parte de la implementación completa, no solo de la interfaz.

- Nunca incluya secretos, credenciales, tokens, URL privadas ni datos bancarios en el repositorio o los logs.
- Trate toda entrada externa como no confiable.
- Valide autenticación y autorización por rol en el servidor; ocultar un control no constituye autorización.
- Almacene localmente solo la información imprescindible y use mecanismos apropiados para datos sensibles.
- No exponga reservas anteriores sin autenticación ni detalles de reservas o pagos en vistas previas y notificaciones.
- Use mensajes discretos y evite contenido explícito o información personal innecesaria.

## Gestión de dependencias

Una dependencia se incorpora solo si resuelve una necesidad real y documentada. Antes de agregarla, evalúe mantenimiento, licencia, vulnerabilidades conocidas, compatibilidad con Flutter, Android e iOS, tamaño, dependencias transitivas, dependencia del proveedor y si Flutter ya resuelve el caso.

No agregue varios paquetes para el mismo propósito. La administración de estado, red, persistencia y navegación definitiva siguen pendientes y deben seleccionarse con la arquitectura. Las dependencias exclusivamente visuales se documentan en [README_DISENO_FLUTTER.md](README_DISENO_FLUTTER.md#3-tecnología-y-librerías-recomendadas).

## Calidad y pruebas

Antes de integrar cambios, ejecute:

```bash
flutter pub get
dart format .
flutter analyze
flutter test
```

No integre errores de análisis, imports sin uso, código inalcanzable, advertencias ignoradas sin justificación, pruebas fallidas, credenciales, temporales o dependencias sin uso.

La estrategia debe incorporar progresivamente:

- Pruebas unitarias.
- Pruebas de widgets.
- Pruebas de integración.
- Pruebas de flujos críticos.

Priorice inicio de sesión, acceso por rol, consulta de moteles y habitaciones, selección y validación de fecha, hora y disponibilidad, creación y cancelación de reservas, productos y servicios, cálculo de valores, pagos y gestión del propietario. Evite pruebas acopladas innecesariamente a detalles internos de los widgets. Los criterios específicos de calidad visual y golden tests permanecen en la guía de diseño.

## Git y pull requests

Los commits deben ser pequeños, coherentes y descriptivos. Se recomienda Conventional Commits:

```text
feat: add motel detail view
fix: prevent selecting unavailable dates
refactor: extract reservation card widget
style: apply reservation screen spacing
test: add reservation total tests
docs: update visual design rules
chore: update Flutter dependencies
```

Use ramas descriptivas como `feature/motel-list`, `feature/room-reservation`, `feature/owner-dashboard`, `fix/reservation-date-validation` o `refactor/shared-buttons`. Evite nombres como `cambios`, `prueba`, `final`, `version2` o nombres personales.

Cada pull request debe explicar qué resuelve, qué modifica, cómo se probó, qué pantallas afecta, las dependencias modificadas, los riesgos y los pendientes. Los cambios visuales deben incluir evidencia.

Lista mínima de verificación:

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
