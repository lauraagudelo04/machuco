# Arquitectura — referencia condensada

## Estructura provisional de lib/ (no reorganizar sin acuerdo de equipo)

| Carpeta | Responsabilidad | No debe contener |
|---|---|---|
| `widgets/` | Componentes reutilizables de verdad, o parte del sistema visual | Lógica de negocio |
| `views/` | Pantallas: presentan info, reciben interacción, muestran estados, delegan lógica | Estilos globales, hexadecimales |
| `models/` | Dominio: `Motel`, `Room`, `Reservation`, `AdditionalService`, `Product`, `Payment`, `Review`, `Subscription`, `PqrsRequest`, `User` | — |
| `controllers/` | Coordinación entre UI, servicios y datos | Toda la lógica concentrada en un solo lugar |
| `routes/` | Rutas centralizadas, acceso por autenticación/rol, separación cliente/propietario | Lógica de negocio |
| `service/` | Operaciones externas o procesos específicos | UI, navegación, transformaciones no relacionadas |
| `data/` | Obtención/representación/almacenamiento de datos, sin asumir fuente concreta | — |
| `repository/` | Contratos que abstraen el origen de datos | Dependencia directa de un proveedor concreto |
| `utils/` | Utilidades pequeñas y concretas (formateadores, validadores, mapeadores) | Archivos genéricos (`helpers.dart`, `varios.dart`) |
| `main.dart` | Inicialización, configuración global, tema, ejecución | — |

## Capa visual (cuando se implemente `core/design_system/`)

```
lib/core/design_system/
├── tokens/        (color, gradiente, radio, sombra, espaciado, texto, movimiento)
├── theme/         (ColorScheme, ThemeData, ThemeExtensions)
├── components/    (buttons, cards, feedback, forms, navigation, status)
└── design_system.dart   (exporta la API pública estable)
```

Flujo de dependencia, en una sola dirección:
`Tokens → ThemeData → Componentes reutilizables → Vistas por feature`.
Los `controllers`/`providers` alimentan la vista con estado; el `router`
decide navegación. Una card **nunca** consulta servicios directamente.

## Convención de rutas (go_router)

```
/login
/client/home
/client/motels/:motelId
/client/motels/:motelId/rooms/:roomId
/client/reservations/new
/client/reservations/:reservationId
/owner/dashboard
/owner/rooms
/owner/reservations/:reservationId
```

Nunca enviar modelos completos por la URL — solo identificadores.

## Dónde va un componente nuevo

- ¿Se reutiliza en 2+ pantallas o es parte del sistema visual (botón,
  card, badge)? → `widgets/` o `core/design_system/components/`.
- ¿Es específico de una sola pantalla/funcionalidad? → junto a la vista,
  dentro de `views/`.
- Antes de crear uno nuevo, revisa si ya existe algo similar — evita
  duplicar componentes entre las 17 ramas del proyecto.
