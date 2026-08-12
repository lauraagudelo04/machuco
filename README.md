# MACHUCO

Aplicación móvil multiplataforma desarrollada con Flutter para consultar, reservar y administrar moteles.

Este documento presenta el contexto general y el estado del proyecto. Las reglas de trabajo y la especificación visual se mantienen por separado:

- [Guía de buenas prácticas](GUIA_MACHUCO.md)
- [Guía de diseño e implementación visual](README_DISENO_FLUTTER.md)

## Índice

1. [Descripción](#descripción)
2. [Objetivo](#objetivo)
3. [Perfiles](#perfiles)
4. [Alcance funcional](#alcance-funcional)
5. [Tecnologías](#tecnologías)
6. [Estructura actual](#estructura-actual)
7. [Estado y decisiones pendientes](#estado-y-decisiones-pendientes)
8. [Próximos pasos](#próximos-pasos)

## Descripción

Machuco centraliza la interacción entre clientes y propietarios de moteles. Busca ofrecer un proceso claro, privado y consistente para descubrir establecimientos, consultar habitaciones, seleccionar fechas, horarios y servicios, y completar una reserva. También proporciona a los propietarios herramientas para consultar y administrar su operación.

El producto debe priorizar:

- Privacidad y seguridad.
- Facilidad de uso y claridad.
- Separación de acceso por roles.
- Consistencia entre Android e iOS.
- Mantenibilidad, escalabilidad y adaptación a distintos tamaños de pantalla.

## Objetivo

Permitir que los clientes encuentren y reserven habitaciones y servicios desde una aplicación móvil, y que los propietarios gestionen establecimientos, disponibilidad, reservas y demás elementos relacionados con su operación.

## Perfiles

### Cliente

Puede explorar establecimientos, consultar habitaciones y disponibilidad, seleccionar productos o servicios adicionales, reservar, pagar, gestionar sus reservas, presentar PQRS y publicar reseñas.

### Propietario

Puede administrar establecimientos, habitaciones, disponibilidad, reservas, productos, servicios, pagos, reseñas y suscripciones mediante un panel diferenciado.

## Alcance funcional

- Autenticación y sesiones.
- Acceso y perfiles según el rol.
- Consulta y gestión de moteles.
- Habitaciones, clases y disponibilidad.
- Creación y administración de reservas.
- Productos y servicios adicionales.
- Pagos y consulta de pagos.
- Reseñas y su gestión.
- PQRS.
- Suscripciones.
- Panel del propietario.

Este alcance describe el producto; todavía no determina la implementación técnica de cada módulo.

## Tecnologías

- Flutter.
- Dart.
- Android Studio.
- Git.

Aún no están definidos el backend, la base de datos, el proveedor de autenticación, la pasarela de pagos, el almacenamiento de imágenes, la administración de estado, la navegación definitiva ni la plataforma de despliegue. Las decisiones aprobadas deberán registrarse en la documentación correspondiente.

## Estructura actual

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

La estructura es provisional hasta que el equipo defina la arquitectura definitiva. La responsabilidad y las reglas de cada directorio se detallan en [GUIA_MACHUCO.md](GUIA_MACHUCO.md#estructura-provisional-del-proyecto).

## Estado y decisiones pendientes

Machuco se encuentra en desarrollo. Antes de modificar significativamente su estructura se deben definir y documentar:

- Arquitectura y administración de estado.
- Backend, base de datos y contratos de API.
- Autenticación, autorización por roles y sesiones.
- Pasarela de pagos y sistema de suscripciones.
- Almacenamiento de imágenes y persistencia local.
- Navegación, enlaces profundos y notificaciones.
- Gestión de secretos y entornos.
- Analítica, monitoreo, CI/CD y alcance de las pruebas automatizadas.
- Términos de privacidad y tratamiento de datos.

## Próximos pasos

1. Acordar la arquitectura y la solución de estado global.
2. Definir backend, contratos de datos y persistencia.
3. Definir autenticación y autorización por roles.
4. Establecer navegación, entornos y gestión de secretos.
5. Configurar pruebas automatizadas y CI/CD.
6. Implementar la interfaz conforme a [README_DISENO_FLUTTER.md](README_DISENO_FLUTTER.md).
