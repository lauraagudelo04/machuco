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
      | Teléfono | +57 300 123 4567 |
      | Dirección | Calle 10 # 43-25, Medellín |
    And El usuario selecciona "Guardar"
    Then Se muestra un mensaje de "Propietario registrado exitosamente"
    Y El propietario aparece en el listado con los datos ingresados
    And El campo "sincronizado" queda en 0 (pendiente de nube)

  Scenario: Editar el teléfono de un propietario existente
    Given Existe un propietario registrado con nombre "Laura Gómez Restrepo"
    And El usuario selecciona el propietario en la lista
    And El usuario selecciona "Editar teléfono"
    When El usuario ingresa el nuevo teléfono "+57 310 987 6543"
    And El usuario selecciona "Guardar cambios"
    Then Se muestra un mensaje de "Teléfono actualizado exitosamente"
    Y El listado muestra el nuevo número de teléfono
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
  - `lib/controllers/owner_management/` — controlador OwnerController (reglas de negocio y validación)
  - `lib/models/owner_management/` — modelos Owner, DocumentType, OwnerStatusFilter
  - `lib/views/owner_management/` — vistas owner_page, owner_form_page, owner_detail_page, owner_summary
  - `lib/service/persistence/sqlite/` — OwnerDao, database_config, migraciones
- **Fuera de alcance (por ahora)**: 
  - Integración con Supabase (nube) — se gestionará después con credenciales individuales
  - Cambios en archivos compartidos `database_config.dart` y `sqlite_database.dart` sin coordinación previa
  - Lógica de reautenticación o migración de base de datos existente a nueva versión

## Definiciones de datos

- **Owner**: entidad con id, fullName, documentType, documentNumber, email, phone, address, isActive
- **DocumentType**: enum { citizenshipCard (CC), foreignerCard (CE), taxId (NIT), passport (Pasaporte), taxIdentity (TI) }
- **OwnerStatusFilter**: filtro { all, active, inactive }
- **synchronized**: flag entero 0/1 que indica si el registro ya fue enviado a la nube