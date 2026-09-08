# Contexto — Ejemplo (rama: ejemplo-reserva-habitacion)

> Este archivo es un ejemplo de referencia, no una funcionalidad real.
> Cópialo y adáptalo con tu propio nombre de rama.

## Rol de usuario que atiende esta funcionalidad

Cliente

Feature: Reserva de habitación

  Scenario: Cliente reserva una habitación disponible
    Given un cliente autenticado está viendo el detalle de una habitación
      "Disponible" de un motel
    When selecciona fecha, horario y confirma la reserva
    Then la habitación queda en estado "Reservada", se crea el registro de
      reserva y el cliente ve la confirmación con los datos de la reserva

  Scenario: Cliente intenta reservar una habitación no disponible
    Given un cliente está viendo el detalle de una habitación en estado
      "Ocupada" o "Mantenimiento"
    When intenta iniciar una reserva
    Then el sistema le impide continuar y muestra el motivo, sin generar
      ninguna reserva

  Scenario: Se pierde la conexión al confirmar
    Given un cliente completó los datos de la reserva y presiona confirmar
    When la conexión falla antes de recibir respuesta
    Then la app muestra un error recuperable con opción de reintentar, sin
      duplicar la reserva si el intento anterior sí se procesó

## Alcance técnico

- **Carpetas donde trabajo**: `lib/views/reservations/`,
  `lib/controllers/reservation_controller.dart`,
  `lib/repository/reservation_repository.dart` (contrato, sin
  implementación de backend real todavía)
- **Depende de**: la vista de detalle de habitación (rama
  `detalle-habitacion`) para el botón "Reservar"
- **De quién depende trabajo mío**: la vista de "Mis reservas" (rama
  `lista-reservas`) consume el modelo `Reservation` que defino aquí
- **Fuera de alcance de esta rama**: pagos (se resuelven en otra
  funcionalidad), notificaciones de cancelación (panel del propietario)
- **Decisiones ya tomadas específicas de esta funcionalidad**: el estado de
  una reserva se maneja con un enum (`pending`, `active`, `upcoming`,
  `completed`, `cancelled`), no con strings sueltos

## Notas para los agentes

- Mientras no exista backend real, `ReservationRepository` debe ser una
  interfaz con una implementación en memoria para poder probar la UI.
