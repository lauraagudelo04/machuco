# Sistema de diseño — tokens condensados

Fuente completa: `README_DISENO_FLUTTER.md`. Aquí solo los valores que se
usan al escribir código; sin las tablas HTML de muestras de color.

Regla general: **nunca hexadecimales sueltos en una vista**. Todo pasa por
`ThemeData`/`ColorScheme` o por estos tokens.

## Color — fondos y superficies (nombre Dart · hex oscuro · hex claro · uso)

| Token | Oscuro | Claro | Uso |
|---|---|---|---|
| `backgroundCanvas` / `canvas` | `#0D0913` | `#F4EFF7` | Exterior, navegación inferior |
| `background` | `#100B18` | `#FAF7FC` | Fondo principal de pantalla |
| `surface` | `#15111F` | `#FFFFFF` | Cards y superficies base |
| `elevated` | `#21182B` | `#F0E8F5` | Inputs, chips, modales, sheets |
| `mediaFallback` | `#291B35` | — | Respaldo mientras carga una imagen |

## Color — texto

| Token | Oscuro | Claro | Uso |
|---|---|---|---|
| `textPrimary` | `#F8F6FF` | `#21152C` | Títulos, datos críticos |
| `textSecondary` | blanco 55% | `#5F5668` | Descripciones |
| `textMuted` | blanco 40% | `#7D7286` | Metadata, labels |
| `textDisabled` | blanco 25% | — | Controles deshabilitados |
| `textOnLight` | `#21152C` | — | Texto sobre fondos claros |
| `border` | blanco 7% | `#21152C` 10% | Separadores y cards |

## Color — marca y acciones (mismo hex en ambos temas)

| Token | Hex | Uso |
|---|---|---|
| `violet` | `#8B5CF6` | Primario, foco, selección |
| `purple` | `#A855F7` | Centro del gradiente, secundario |
| `fuchsia` | `#D946EF` | Final del gradiente, acento |
| `fuchsiaText` | `#F0ABFC` | Texto/acento legible sobre oscuro |
| `fuchsiaSoft` | `#F5D0FE` | Highlights pequeños |
| `rose` | `#FB7185` | Error, cancelar, eliminar |

Gradiente de marca (violeta → púrpura → fucsia): **solo** en CTA principal,
FAB, onboarding y acentos excepcionales. Nunca en cards de contenido.

## Color — estados semánticos (habitación)

| Estado | Texto | Fondo | 
|---|---|---|
| Disponible | `#6EE7B7` | verde 12% |
| Reservada | `#A78BFA` | violeta 15% |
| Ocupada | `#E879F9` | fucsia 15% |
| Limpieza | `#FDE68A` | amarillo 12% |
| Mantenimiento | `#FCD34D` | amarillo 12% |
| Bloqueada | `#FECDD3` | rose 12% |
| Fuera de servicio | `#FECDD3` | rose 8% |

Reservas: activa = fucsia, próxima = violeta, completada = verde,
cancelada = rose. Ningún estado depende solo del color: siempre texto o
icono acompañando.

## Espaciado (escala base 4px) y radios

| Espacio | px | Radio | px |
|---|---:|---|---:|
| `s1` | 4 | `sm` | 8 |
| `s2` | 8 | `md` | 12 |
| `s3` | 12 | `lg` | 16 |
| `s4` | 16 | `xl` | 20 |
| `s5` | 20 | `xxl` | 24 |
| `s6` | 24 | `pill` | 9999 |
| `s8` | 32 | | |
| `s12` | 48 | | |

Padding horizontal estándar de pantalla: 20px (16px en pantallas muy
estrechas). En tablet, limitar el ancho del contenido, no estirarlo.

## Bordes y sombras

- Borde normal: blanco 7% · Borde fuerte: blanco 12%
- Borde de foco: violeta 44% (o sólido si se necesita más contraste)
- CTA: sombra violeta suave `0 8 28` @35%
- FAB: sombra violeta suave `0 8 28` @40%
- Cards: elevación por superficie/borde, no por sombras intensas

## Movimiento

| Token | Duración | Uso típico |
|---|---:|---|
| `fast` | 120ms | Presión/selección (100–160ms) |
| `normal` | 220ms | Aparición de contenido (180–240ms) |
| `slow` | 360ms | Cambio de pantalla/sheet (250–360ms) |

Curvas: `standard = easeOutCubic`, `emphasized = easeInOutCubicEmphasized`.
Respetar `MediaQuery.disableAnimations` (reducir a fades breves o nada).

## Tipografía (Inter)

| Rol | Tamaño | Peso | Altura | Uso |
|---|---:|---:|---:|---|
| Display | 28–32 | 800 | 1.2 | Bienvenida/hero |
| H1 | 24 | 700 | 1.3 | Título de pantalla |
| H2 | 20 | 700 | 1.4 | Título de detalle |
| H3 | 18 | 600 | 1.5 | Sección |
| Body large | 15 | 500 | 1.6 | Botones, texto destacado |
| Body | 14 | 400 | 1.5 | Cuerpo, inputs |
| Body small | 13 | 400 | 1.5 | Descripciones |
| Caption | 12 | 500 | 1.4 | Badges, metadata |
| Micro | 10 | 600 | 1.4 | Labels cortos en mayúscula |

No usar tamaños <12px para información necesaria. Probar con escalado de
texto ≥200%. Precios con `NumberFormat.currency(locale: 'es_CO', symbol: r'$')`.

## Iconografía

Tamaño estándar 20–24px; compactos en badges 14–18px. Área táctil mínima
del botón que lo contiene: 48×48px. No mezclar Filled/Outlined/Rounded sin
regla. Todo icono sin texto necesita `tooltip` + etiqueta semántica.

## Catálogo mínimo de componentes

`AppButton`, `AppIconButton`, `AppTextField`, `AppSearchField`, `AppCard`,
`RoomCard`, `MotelCard`, `StatusBadge`, `FilterChipGroup`, `AppBottomSheet`,
`AppDialog`, `AppNavigationBar`, `AppEmptyState`, `AppErrorState`,
`AppSkeleton`. Antes de crear un componente nuevo, revisa si alguno de
estos ya resuelve el caso.
