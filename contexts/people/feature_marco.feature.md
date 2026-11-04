# Contexto — Marco (rama: feature_marco)

## Rol de usuario que atiende esta funcionalidad

Propietario y Administrador del sistema.

Esta rama es dueña de la **administración de moteles**: el Propietario
registra, edita y activa/desactiva sus propios moteles; el Administrador del
sistema hace lo mismo sobre los moteles de toda la plataforma. Los datos se
consultan y guardan en Supabase (API REST) con caché local en Floor, y el
indicativo telefónico se toma del maestro de indicativos en Supabase.

## Feature: Administración de moteles del Propietario

  Scenario: Propietario ve solo sus moteles
    Given un propietario autenticado
    When abre la vista "Mis moteles"
    Then ve únicamente los moteles cuyo owner_id es su id de usuario autenticado

  Scenario: Propietario registra un motel
    Given un propietario en el formulario de motel
    When completa nombre, NIT, dirección, correo, teléfono con indicativo, cantidad de habitaciones y al menos un método de pago, y guarda
    Then el motel queda registrado en Supabase asociado a su owner_id
    And aparece en su listado

  Scenario: Formulario con datos inválidos
    Given un propietario en el formulario de motel
    When deja campos obligatorios vacíos o con formato inválido (NIT, correo, teléfono, habitaciones)
    Then el formulario muestra el mensaje de validación de cada campo y no guarda

  Scenario: NIT duplicado
    Given un motel ya registrado con un NIT
    When se intenta registrar otro motel con el mismo NIT
    Then se muestra un mensaje claro de NIT duplicado y no se crea el motel

  Scenario: Propietario edita o activa/desactiva su motel
    Given un motel propio
    When lo edita o cambia su estado activo
    Then el cambio se guarda en Supabase (PATCH) y se refleja en el listado

## Feature: Administración de moteles del Administrador del sistema

  Scenario: Administrador ve todos los moteles
    Given un administrador del sistema autenticado
    When abre la vista de moteles
    Then ve los moteles de todos los propietarios, con el nombre del propietario

  Scenario: Administrador crea, edita o activa/desactiva un motel
    Given un administrador en la vista de moteles
    When registra, edita o cambia el estado de un motel
    Then el cambio se guarda con las mismas validaciones del formulario del propietario

## Feature: Datos sin conexión

  Scenario: Falla la red con caché disponible
    Given moteles o indicativos previamente cacheados en Floor
    When falla la consulta a Supabase
    Then se muestran los datos de la caché

  Scenario: Falla la red sin caché
    Given no hay datos cacheados
    When falla la consulta a Supabase
    Then se muestra un error claro al usuario

## Alcance técnico

- **Carpetas donde trabajo**: lib/views/motel/owner_view, lib/views/motel/system_admin_view,
  lib/widgets/motel, lib/controllers/motel, lib/models/motel,
  lib/database/model/motel, lib/database/repository/motel,
  lib/utils/motel_form_validators.dart, test/repositories/motel,
  test/utils/motel_form_validators_test.dart
- **Depende de**: autenticación (Firebase Authentication) para obtener el id
  y rol del usuario actual.
- **De quién depende trabajo mío**: vistas de cliente de moteles, PQRS y
  reservas usan `MotelController` / `Motel` — avisar de cambios en su API.
- **Fuera de alcance de esta rama**: vistas de cliente
  (lib/views/motel/client_view), reservas, pagos, PQRS, notificaciones,
  reseñas, almacenamiento de imágenes.
- **Decisiones ya tomadas específicas de esta funcionalidad**: Supabase REST
  para moteles e indicativos; Floor como caché local.

## Notas para los agentes

- `MotelController.getMyMotels()` todavía usa un owner_id fijo
  ('owner-1020304050'); debe reemplazarse por el usuario autenticado y el
  filtro por dueño debe hacerse en la consulta al backend.
- Repositorio de indicativos unificado (acordado con Juan José):
  `PhoneCountryCodeRepository` en
  lib/database/repository/phone_country_code/supabase_phone_country_code_repository.dart.
  Juan José migra client_controller a ese repositorio y borra
  `CountryCodeRepository` en su rama; no tocar sus archivos desde esta rama.
