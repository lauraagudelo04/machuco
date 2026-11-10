# Contexto — Julian (rama: feature_juliang)

> Copia este archivo a `contexts/people/feature_juliang.feature.md`
> y complétalo. El nombre del archivo debe coincidir con el de la rama para
> que los agentes lo encuentren automáticamente.

## Rol de usuario que atiende esta funcionalidad

Cliente | Propietario | Administrador del sistema

Feature: CRUD de propietarios de moteles — registro, edición y consulta

  Scenario: Registrar un nuevo propietario con tipo de documento y teléfono
    Given El sistema está en la pantalla de propietarios
    And El usuario está autenticado como administrador
    When El usuario selecciona "Añadir propietario"
    And El usuario completa el formulario con:
      | Nombre completo | Laura Gómez Restrepo |
      | Tipo de documento | CC |
      | Número de documento | 1020304050 |
      | Correo electrónico | laura.gomez@machuco.com |
      | Indicativo | +57 |
      | Teléfono | 300 123 4567 |
      | Dirección | Calle 10 # 43-25, Medellín |
    And El usuario selecciona "Guardar"
    Then Se muestra un mensaje de "Propietario registrado exitosamente"
    Y El propietario aparece en el listado con los datos ingresados
    And El campo "sincronizado" queda en 0 (pendiente de nube)

  Scenario: Editar el teléfono de un propietario existente
    Given Existe un propietario registrado con nombre "Laura Gómez Restrepo"
    And El usuario selecciona el propietario en la lista
    And El usuario selecciona "Editar teléfono"
    When El usuario ingresa el nuevo teléfono "310 987 6543"
    And El usuario selecciona "Guardar cambios"
    Then Se muestra un mensaje de "Teléfono actualizado exitosamente"
    Y El listado muestra el nuevo número de teléfono con su indicativo "+57 310 987 6543"
    Y El detalle del propietario refleja el cambio

  Scenario: Activar/desactivar a un propietario
    Given Existe un propietario registrado con nombre "Simón Restrepo Vélez" y estado inactivo
    When El usuario selecciona el propietario y elige "Inactivar"
    And Confirma la acción de desactivación
    Then El propietario se marca como inactivo en el listado
    Y El propietario no puede administrar sus moteles ni recibir reservas
    And Se muestra un mensaje de "Propietario desactivado exitosamente"

  Scenario: Buscar un propietario por nombre o documento
    Given Hay varios propietarios registrados en el sistema
    When El usuario ingresa "Laura" en el buscador
    And Presiona la lupa para buscar
    Then El listado filtra mostrando solo propietarios con "Laura" en el nombre
    And El conteo total refleja la coincidencia encontrada

  Scenario: Filtrar propietarios por estado activo/inactivo
    Given Hay propietarios registrados con estados mixto (algunos activos, algunos inactivos)
    When El usuario selecciona el filtro "Solo activos"
    Then El listado muestra solo los propietarios con estado activo
    And El filtro "Todos" restaura el listado completo

## Alcance técnico

- **Carpetas donde trabajo**:
  - `lib/controllers/owner_management/` — `OwnerController` (estado de la vista, validación por país, sincronización)
  - `lib/models/owner_management/` — modelos `Owner`, `DocumentType`, `OwnerStatusFilter` y `OwnerUserDocument`
  - `lib/service/owner/` — `OwnerService` (reglas de negocio) y `OwnerPreferences` (shared_preferences)
  - `lib/repositories/owner/` — `OwnerCloudRepository` y la implementación Firestore
  - `lib/views/owner_management/` — vistas `owner_page`, `owner_form_page`, `owner_detail_page`, `owner_summary`
  - `lib/database/model/owner/`, `lib/database/model/document_type/` y sus repositorios — entidades Floor y DAOs
- **Firestore (datos de dominio)**: cada propietario es un usuario registrado en `users/{uid}` con `role = owner`; documento `owner_user_document.dart`, repositorio de nube, reglas de seguridad y sincronización push + pull + merge.
- **Supabase (solo maestros)**: tabla `document_types` con su SQL en `supabase/migrations/`, consultada por **REST + `http`**. No se instala `supabase_flutter`.
- **shared_preferences**: namespace `owners` para el último indicativo; namespace `auth` para el correo del administrador.
- **Fuera de alcance**:
  - Tabla `owners` en Supabase (los propietarios van a Firestore).
  - Tareas Supabase/Firebase de otras entidades (pagos, clientes, reservas, moteles).
  - Cambios en archivos compartidos (`lib/database/app_database.dart`, `app_database.g.dart`) sin coordinación previa de número de migración.
- **Migraciones**: tras el merge con `develop` (que dejó la 14 con `auth_user_profile`), el módulo ocupa `14→15` (crea `owners` con indicativo y `document_types`), `15→16` (`pendingDelete`), `16→17` (reconcilia una base v16 de esta rama), `17→18` (`accountStatus`) y `18→19` (borra filas locales heredadas `owner-*`). Esquema local en **19**.

## Definiciones de datos

- **Owner**: `id` (uid de Firebase Auth), `fullName`, `documentType`, `documentNumber`, `email`, `phone` (número nacional), `countryCode` (`+57`), `countryName` (`Colombia`), `address`, `isActive`, `accountStatus`, `isSynchronized`.
- **phoneWithDialCode**: teléfono listo para mostrar, por ejemplo `+57 300 123 4567`.
- **DocumentType**: enum { citizenshipCard (CC), foreignerCard (CE), taxId (NIT), passport (PAS), identityCard (TI) }. El maestro local `document_types` guarda `code`, `name`, `pattern`, `example`, `isActive` y `sortOrder`; es la fuente del selector y se siembra con los cinco códigos.
- **OwnerStatusFilter**: filtro { all, active, inactive }.
- **synchronized**: flag entero 0/1 que indica si el registro ya fue enviado a la nube.

## Escenarios nuevos

  Scenario: Elegir el indicativo del país al registrar un propietario
    Given El usuario está en el formulario de nuevo propietario
    When El usuario toca el selector de indicativo
    Then Se abre un buscador por nombre de país, código ISO o indicativo
    And Puede elegir cualquier país del maestro (por ejemplo +1, +44 o +52)
    And El indicativo elegido se guarda aparte del número nacional

  Scenario: Rechazar un teléfono con longitud inválida para el país
    Given El usuario eligió Colombia (+57) en el selector
    When El usuario ingresa un número nacional de 6 dígitos
    And El usuario selecciona "Guardar"
    Then El sistema bloquea el envío
    And Muestra un mensaje indicando cuántos dígitos se esperan para Colombia

  Scenario: Crear un propietario desde el panel
    Given El usuario está autenticado como administrador con Firebase
    When El usuario registra un propietario con conexión
    Then Se crea su cuenta de Firebase Auth con una contraseña temporal
    And Se escribe users/{uid} con role = owner y los datos legales
    And El resumen muestra la contraseña temporal una sola vez
    And La fila local queda con synchronized = 1 y el uid como id

  Scenario: Crear un propietario sin conexión
    Given El dispositivo está en modo avión
    When El usuario intenta registrar un propietario
    Then El sistema explica que necesita conexión para crear la cuenta de acceso
    And No se guarda ninguna fila local

  Scenario: Editar sin conexión y recuperar la sincronización sola
    Given El dispositivo está en modo avión
    When El usuario edita los datos de un propietario
    Then El cambio se conserva en SQLite con synchronized = 0
    And La pantalla muestra un aviso con el intento automático en curso
    When El usuario recupera la conexión
    Then La app reintenta sola con retroceso (2 s, 5 s, 10 s, 30 s, 60 s)
    And El cambio pendiente se envía a users
    And El aviso desaparece

  Scenario: El propietario ve sus propios datos en la vista de moteles
    Given El propietario inició sesión con Firebase
    When Abre la pantalla de moteles
    Then El menú muestra "Sesión: {nombre real}" y el chip su primer nombre
    And Solo se listan los moteles cuyo owner_id es su uid
    And No aparece ningún selector de propietarios de ejemplo

  Scenario: El propietario edita su perfil
    Given El propietario inició sesión con Firebase
    When Abre "Mi perfil" desde el menú
    Then Ve su nombre, correo, teléfono, documento y estado de cuenta
    And Puede cambiar su nombre y su teléfono
    And No puede cambiar su correo, documento ni estado

  Scenario: El propietario cambia su contraseña desde el perfil
    Given El propietario inició sesión con Firebase
    When Abre "Cambiar contraseña" desde su perfil
    And Escribe una contraseña nueva y la confirma
    Then Firebase Auth actualiza la contraseña
    And Si la cuenta era de contraseña temporal, se limpia mustChangePassword
    And La app informa "Contraseña actualizada correctamente"

  Scenario: Reasignar moteles al eliminar un propietario
    Given El propietario tiene al menos un motel vinculado en Supabase
    When El administrador confirma su eliminación
    Then El sistema no elimina la cuenta todavía
    And Abre un cuadro con los nombres de sus moteles
    And Muestra los demás propietarios para elegir el destino
    When El administrador elige un destino y confirma
    Then Los moteles se reasignan a ese propietario en Supabase
    And La cuenta del propietario eliminado se borra

  Scenario: No se puede eliminar si la reasignación falla
    Given El propietario tiene moteles vinculados
    And La reasignación falla por falta de conexión
    When El administrador confirma la transferencia
    Then No se elimina la cuenta ni la fila local
    And Se informa que los moteles no se pudieron reasignar

  Scenario: Eliminar un propietario sin conexión
    Given El dispositivo está en modo avión
    And Existe un propietario sincronizado en Firestore
    When El usuario elimina el propietario
    Then La fila local queda con pendingDelete = 1 y se oculta del listado
    And El documento users/{uid} sigue en Firestore
    When El usuario recupera la conexión
    Then La sincronización borra el documento users/{uid}
    And La fila local se elimina por completo
    And El pull posterior no resucita al propietario

  Scenario: Incorporar propietarios creados en otro dispositivo
    Given Existe un usuario con role = owner en users de Firestore
    And No existe en el SQLite de este dispositivo
    When El usuario abre la pantalla de propietarios
    Then El propietario remoto se inserta en SQLite ya marcado como sincronizado
    And Aparece en el listado local

  Scenario: Recordar el último indicativo usado
    Given El usuario registró un propietario con el indicativo +52
    When El usuario abre el formulario de nuevo propietario
    Then El selector de indicativo aparece preseleccionado en +52

  Scenario: Actualizar el maestro de tipos de documento desde Supabase
    Given La tabla document_types está publicada en Supabase
    When El usuario abre el formulario de propietarios con conexión
    Then La app consulta el maestro por REST
    And Reemplaza la caché local de document_types
    And El selector muestra los tipos activos ordenados por sort_order

## Tareas futuras (no implementadas)

- **Eliminar los moteles** desde el cuadro de transferencia, para cuando no se
  quieran reasignar a otro propietario.
- **Guard de contraseña temporal para propietarios**: si `mustChangePassword`
  está activo al iniciar sesión, exigir el cambio antes de entrar (hoy el
  cambio está disponible solo desde «Mi perfil»).
