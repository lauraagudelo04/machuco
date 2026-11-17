# Funcionalidad: Productos del motel

## ¿Qué es?

Permite que cada motel tenga su propio **catálogo de productos** (por ejemplo,
bebidas, preservativos, lubricantes o accesorios) que el propietario administra
desde la app y que los clientes pueden ver y elegir al hacer una reserva.

Los productos se guardan en la **base de datos en la nube (Firebase)**, por lo
que la información es la misma en todos los dispositivos y no se pierde si se
cierra o se reinstala la app.

---

## ¿Qué puede hacer el propietario?

| Acción | Descripción |
|---|---|
| **Ver el catálogo** | Lista de todos los productos de su motel, con nombre, descripción, precio, stock y estado (disponible / no disponible). |
| **Buscar productos** | Barra de búsqueda sobre la lista: filtra mientras se escribe, por nombre o descripción, sin importar mayúsculas ni tildes. Si no hay coincidencias, se muestra el mensaje "Sin resultados". |
| **Crear un producto** | Formulario con nombre, descripción (opcional), precio, stock y si está disponible. |
| **Editar un producto** | Permite actualizar cualquiera de esos datos. |
| **Activar / desactivar** | Un botón rápido para mostrar u ocultar un producto sin borrarlo. |
| **Eliminar un producto** | Con confirmación previa para evitar borrados accidentales. |
| **Ver el detalle** | Al tocar un producto se abre su información completa. |

### Navegación
- En el formulario de producto hay una **flecha para volver** en la barra
  superior y un botón **Cancelar** al final del formulario, para salir sin
  guardar cambios.
- El formulario valida los datos antes de guardar (nombre obligatorio, precio y
  stock válidos) y muestra mensajes claros en español.

---

## ¿Qué ve el cliente?

Al crear una reserva, el cliente ve los productos de **ese motel** que estén
**disponibles y con stock**, y puede agregarlos a su reserva. Los productos
desactivados o agotados no aparecen.

---

## Seguridad y reglas de acceso

La validación se hace en el servidor (Firebase), no solo en la pantalla:

- **Cualquier usuario con sesión iniciada** puede consultar los productos.
- **Solo el propietario activo del motel** (o el administrador del sistema)
  puede crear, editar o eliminar sus productos.
- Un propietario **no puede** crear ni modificar productos en moteles que no
  son suyos.
- Un producto **no puede cambiarse de motel ni de dueño** una vez creado.
- Los datos se validan: el nombre no puede estar vacío, el precio y el stock no
  pueden ser negativos y el stock debe ser un número entero.
- Los clientes no pueden escribir productos, aunque intenten hacerlo por fuera
  de la app.

---

## Comportamiento ante fallos de conexión

- Si no hay conexión al **consultar**, la app muestra la última copia guardada
  en el dispositivo para que el propietario pueda seguir viendo su catálogo.
- Si no hay conexión o faltan permisos al **crear, editar o eliminar**, la app
  muestra un mensaje de error y **no deja cambios a medias**: lo que se ve en
  pantalla siempre coincide con lo guardado.

---

## Datos que se almacenan por producto

| Campo | Descripción |
|---|---|
| Nombre | Obligatorio, hasta 100 caracteres. |
| Descripción | Opcional, hasta 500 caracteres. |
| Precio | Valor en pesos, mayor o igual a 0. |
| Stock | Unidades disponibles (entero, mayor o igual a 0). |
| Disponible | Indica si se muestra a los clientes. |
| Motel y propietario | Asociación al motel y a su dueño (no editable). |
| Fecha de actualización | Registrada automáticamente por el servidor. |

---

## Alcance actual y puntos pendientes

Para ser transparentes sobre lo entregado en esta etapa:

- **Incluido:** administración completa del catálogo (crear, ver, buscar,
  editar, activar/desactivar, eliminar), almacenamiento en Firebase, reglas de
  seguridad por rol y visualización de productos al reservar.
- **No incluido aún:**
  - **Fotos de los productos:** el sistema ya reserva el espacio para la imagen,
    pero la forma de almacenarlas todavía no se ha definido como equipo.
  - **Descuento automático de stock** al reservar un producto: requiere definir
    primero las reglas de negocio (por ejemplo, cuándo se descuenta y qué pasa
    si la reserva se cancela).

---

## Pruebas realizadas

- Pruebas automáticas del controlador de productos (sincronización con la
  nube, uso de copia local ante fallos, escritura con el propietario correcto y
  modo sin sesión).
- Pruebas de reglas de seguridad escritas para los casos de permisos y datos
  inválidos (pendientes de ejecutarse en un entorno con el emulador de Firebase).
- Verificación manual: creación de un producto desde la app y confirmación de
  que aparece en la base de datos de Firebase.
