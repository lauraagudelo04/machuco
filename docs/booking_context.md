# Contexto del Proyecto: Sistema de Gestión de Reservas para Moteles

**Objetivo:** Desarrollar el flujo de usuario y la lógica de interfaz para un aplicativo de reservas de moteles. El sistema debe manejar múltiples roles, control de estados de reservas y visualización de estadísticas.

**Glosario de Estados de Reserva:**
Para comprender la lógica de los botones y acciones, la reserva transita por los siguientes estados:
*   `pending`: Reserva creada pero pendiente de pago.
*   `upcoming`: Reserva pagada/confirmada, fecha de ingreso en el futuro.
*   `active`: Cliente actualmente en el motel.
*   `completed`: Estancia finalizada.
*   `cancelled`: Reserva anulada (requiere motivo).

A continuación, se detallan los flujos funcionales y requerimientos de interfaz divididos por los tres roles principales del sistema: Cliente, Propietario y Administrador.

---

## 1. Flujo del Rol: Cliente

### 1.1 Proceso de Reserva
*   **Inicio:** Al iniciar sesión, el cliente es dirigido a la **Lista de Moteles**.
*   **Selección de Motel:** Al ingresar a un motel, se visualiza la opción de ver las habitaciones. Esta vista filtra y muestra únicamente los tipos de habitaciones disponibles en ese motel.
*   **Formulario de Reserva:** Al seleccionar un tipo de habitación, se despliega el formulario con los siguientes elementos:
    *   *Encabezado:* Información básica del motel y el tipo de habitación seleccionada.
    *   *Fechas:* Selector (calendario) para fecha y hora de entrada y salida.
    *   *Huéspedes:* Selector de cantidad de personas (validado para no superar el límite máximo permitido por el tipo de habitación).
    *   *Adicionales:* Listado de productos y servicios adicionales ofrecidos por el motel.
    *   *Acción:* Botón **[Reservar]**.
*   **Resumen de la Reserva:** Tras presionar "Reservar", el cliente es llevado a una pantalla de resumen que incluye:
    *   Nombre del motel y tipo de habitación.
    *   Habitación específica asignada por el sistema.
    *   Fechas y horas seleccionadas.
    *   Cantidad de personas.
    *   Desglose de costos (habitación + productos/servicios adicionales).
    *   Costo total de la reserva.
    *   Botón **[Ir a Pagar]**.

### 1.2 Gestión de Mis Reservas
*   **Lista de Reservas:** Vista con tarjetas que resumen la información y el estado actual de todas las reservas asociadas al cliente.
*   **Detalle de la Reserva:** Al presionar una tarjeta, se muestra la información detallada con un panel inferior de acciones dinámicas según el estado de la reserva:
    *   **[Ver Factura]:** Visible solo si el estado es `active`, `upcoming` o `completed`.
    *   **[Añadir Reseña]:** Visible solo si el estado es `completed` o `cancelled`.
    *   **[Completar Pago]:** Visible solo si el estado es `pending`.
    *   **[Cancelar Reserva]:** Visible solo si el estado es `pending` o `upcoming`.
        *   *Flujo de cancelación:* Abre un modal de confirmación. Al confirmar, despliega un campo de texto obligatorio para ingresar el "Motivo de cancelación". Una vez cancelada, este motivo debe ser visible permanentemente en los detalles de la reserva.

---

## 2. Flujo del Rol: Propietario

*   **Inicio:** Al iniciar sesión, visualiza un Menú Principal con la lista de sus moteles registrados.
*   **Navegación Inferior:** Incluye accesos directos a "Reservas Generales" y "Clientes".

### 2.1 Ventana de Reservas Generales
*   **Listado y Filtros:** Muestra todas las reservas asociadas a los moteles del propietario, presentadas en formato de tarjetas con información clave para identificación rápida. Incluye filtros por: Motel, Estado, y ordenamiento cronológico (más recientes primero).
*   **Detalle y Acciones Administrativas:** Al ingresar a una reserva específica, el propietario tiene las siguientes opciones:
    *   **[Pagar en Efectivo]:** Dirige a una pantalla con el detalle de cobro y un botón de confirmación de pago que, al accionarse, genera y muestra la factura.
    *   **[Cancelar Reserva]:** Visible solo si el estado es `pending` o `upcoming`.
        *   *Flujo de cancelación:* Abre modal de confirmación -> Solicita "Motivo de cancelación" (campo de texto) -> Cambia estado a `cancelled` -> Añade el motivo al detalle de la reserva -> **Dispara una notificación automática al cliente.**

### 2.2 Ventana de Clientes
*   **Listado:** Muestra un directorio de clientes que han interactuado con los moteles del propietario.
*   **Detalle del Cliente:** Permite ejecutar varias acciones administrativas, siendo la principal: visualizar el historial completo de reservas de ese cliente (exclusivamente las asociadas a los moteles de este propietario).

---

## 3. Flujo del Rol: Administrador del Sistema

*   **Inicio:** Al iniciar sesión, visualiza una lista general de todos los propietarios registrados en la plataforma.
*   **Gestión por Propietario:** Al seleccionar un propietario, se listan los moteles que este tiene asociados.
*   **Navegación de Motel:** En la vista detallada de los moteles de un propietario, un menú inferior permite acceder a diferentes módulos, entre ellos, el módulo de **Reservas**.

### 3.1 Ventana de Estadísticas de Reservas
*   **Vista General:** Muestra la lista de moteles del propietario seleccionado, acompañados de KPIs básicos (ej. promedio de reservas mensuales).
*   **Dashboard Detallado (Por Motel):** Al seleccionar un motel específico, se despliega un panel analítico completo que incluye:
    *   Indicador numérico del total histórico de reservas recibidas.
    *   Gráfico de líneas/barras comparativo de la evolución de reservas en el último año.
    *   Filtros interactivos en el gráfico para segmentar por estado de la reserva (`completed`, `cancelled`, etc.).
    *   Desglose y totalización de reservas pagadas, categorizadas por método de pago.
    *   *Nota para el LLM (Claude):* Se requiere analizar este contexto y sugerir qué otros elementos, métricas o gráficos estadísticos aportarían valor a este panel gerencial.