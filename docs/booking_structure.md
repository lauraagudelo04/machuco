# Estructura del contexto booking

El contexto `booking` se organiza primero por capa y después por el rol que
consume cada caso de uso. Los nombres de rol aprobados son `client_view`,
`owner_view` y `system_admin_view`.

```text
lib/
├── controllers/booking/
│   ├── client_view/client_booking_controller.dart
│   ├── owner_view/owner_booking_controller.dart
│   └── system_admin_view/system_admin_booking_controller.dart
├── models/booking/
│   └── booking.dart
├── routes/
│   └── routes.dart
└── views/booking/
    ├── client_view/
    │   ├── client_booking_home_page.dart
    │   ├── create_booking_page.dart
    │   └── booking_detail_page.dart
    ├── owner_view/
    │   └── owner_booking_home_page.dart
    └── system_admin_view/
        └── system_admin_booking_home_page.dart
```

`models/booking/booking.dart` es compartido de forma intencional: una reserva
es la misma entidad de dominio para los tres roles. Las diferencias de acceso,
datos y presentación se mantienen en controladores, rutas y vistas por rol.

`AppRoutes.bookingHomeFor` es el punto de integración para autenticación. Al
recibir el rol de la sesión devuelve el home correcto; por ahora la raíz de la
aplicación conserva el selector visual de roles para facilitar el desarrollo.

Las nuevas páginas de reservas deben agregarse en el rol correspondiente y su
ruta debe declararse en `lib/routes/routes.dart`, el único archivo central de
rutas de la aplicación. Solo los elementos realmente compartidos entre varios
roles deben permanecer en la raíz del contexto.
