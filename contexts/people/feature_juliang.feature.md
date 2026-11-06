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
  - `lib/controllers/owner_management/` — `OwnerController` (estado de la vista, validación por país)
  - `lib/models/owner_management/` — modelos `Owner`, `DocumentType`, `OwnerStatusFilter`
  - `lib/service/owner/` — `OwnerService` (reglas de negocio y orquestación)
  - `lib/views/owner_management/` — vistas `owner_page`, `owner_form_page`, `owner_detail_page`, `owner_summary`
  - `lib/database/model/owner/` y `lib/database/repository/owner/` — entidad Floor `OwnerEntry` y `OwnerDao`/`OwnerRepository`
- **Supabase (solo lo que toca propietarios)**: esquema SQL de la tabla remota de owners, su mapeo 1:1, el repositorio de nube y la sincronización de owners. Se hace con **REST + `http`**, igual que el resto del equipo; **no** se instala `supabase_flutter`.
- **Fuera de alcance**:
  - Tareas Supabase de otras entidades (pagos, clientes, reservas, moteles).
  - `supabase_flutter` y la migración de las llamadas REST existentes.
  - Cambios en archivos compartidos (`lib/database/app_database.dart`, `app_database.g.dart`) sin coordinación previa de número de migración.
- **Migraciones**: `12→13` crea `owners`; `13→14` separa el indicativo. Los números siguientes deben coordinarse con el equipo porque otras ramas también suben la versión.

## Definiciones de datos

- **Owner**: `id`, `fullName`, `documentType`, `documentNumber`, `email`, `phone` (número nacional), `countryCode` (`+57`), `countryName` (`Colombia`), `address`, `isActive`, `isSynchronized`.
- **phoneWithDialCode**: teléfono listo para mostrar, por ejemplo `+57 300 123 4567`.
- **DocumentType**: enum { citizenshipCard (CC), foreignerCard (CE), taxId (NIT), passport (Pasaporte), taxIdentity (TI) }.
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