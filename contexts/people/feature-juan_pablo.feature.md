# Contexto - Funcionalidad de autenticación: login y registro (rama: feature-juan_pablo)

> **Cambio de funcionalidad**: esta rama dejó de ser dueña del módulo
> "Bookings". Ahora es dueña del **módulo de autenticación** (inicio de
> sesión, registro, recuperación de contraseña, sesión persistente y cierre
> de sesión), de la **creación de administradores** y de la **aprobación de
> propietarios** desde la vista del administrador. El código de bookings ya
> construido permanece en el repositorio pero no debe modificarse desde esta
> rama salvo para corregir una ruptura causada por cambios de autenticación.

## Rol del usuario

Visitante no autenticado (antes del login) y, después de autenticarse,
Cliente, Propietario o Administrador del sistema.

Es una sola funcionalidad ("acceso a la aplicación") que sirve a los tres
roles: todos usan la misma pantalla de login y el mismo `LoginController`; lo
único que cambia por rol es la ruta de destino después de autenticarse. El
Administrador además tiene dos vistas propias de esta rama: "Administradores"
(crear otros administradores) y "Solicitudes de propietarios" (aprobar o
rechazar cuentas `pending_approval`).

## Decisiones de esta rama

- **Proveedor de seguridad: exclusivamente Firebase Authentication**
  (identidad, sesión, correo/contraseña y recuperación de contraseña).
- **Proveedor de almacenamiento: Firebase**. El perfil del usuario (incluidos
  NIT y tipo de persona), las solicitudes de propietarios y los archivos se
  guardan en Firebase (Cloud Firestore y/o Cloud Storage, pendiente de
  confirmar cuál) protegidos por reglas de seguridad. Los **maestros** siguen
  en Supabase.
- **Proveedores externos (Google/Gmail y GitHub): solo definidos, no
  implementados**. Se ingresarán más adelante a través de Firebase Auth y en
  cooperación con otras ramas. En esta rama solo se dejan escritos sus
  escenarios (ver "Ingreso con proveedores externos [Futuro]"); no se agregan
  dependencias, botones funcionales ni lógica para ellos.
- **Login quemado temporal**: Firebase Auth ya está integrado; el
  `HardcodedAuthService` (usuarios de prueba por rol) queda solo como
  herramienta de desarrollo y se activa con
  `--dart-define=AUTH_USE_HARDCODED_AUTH_USERS=true`. **No se elimina por
  ahora**, pero es transitorio: cuando el equipo ya no lo necesite se retiran
  el `HardcodedAuthService`, la feature "Acceso local temporal" y todos los
  escenarios marcados como **[Temporal]**.
- **Contrato `AuthService` en retirada**: el contrato existe solo como puente
  mientras conviven el login quemado y Firebase. Los escenarios nuevos se
  escriben contra **Firebase Auth**; no se deben agregar escenarios ni
  capacidades nuevas que dependan del contrato `AuthService` como abstracción
  multiproveedor. Cuando el login quemado desaparezca, el controller podrá
  hablar con un servicio de Firebase Auth sin la capa genérica.
- **Registro público solo para Cliente y Propietario**. Los administradores
  **no se registran desde la pantalla principal**: solo otro administrador
  puede crearlos desde la vista "Administradores". Se descarta el mecanismo
  de código de invitación.
- **SharedPreferences**: preferencias locales no sensibles del login y el
  **correo del usuario autenticado**, que se comparte entre pantallas y
  funcionalidades, a través de `LocalPreferencesService` con namespace
  `auth`.
- **SQLite (Floor / `AppDatabase`)**: caché local de los maestros de Supabase
  y del perfil básico del usuario autenticado.
- **Supabase**: fuente de los maestros de **indicativo telefónico por país**
  y de **planes de suscripción para propietarios**, consumidos por REST
  (`/rest/v1/...`) con el mismo patrón de `RoomServiceRepository` (caché
  primero, red después). El maestro de planes reutiliza la tabla
  `subscription_plans` que ya consume la rama de suscripciones; se amplía en
  coordinación con ella, no se duplica.
- **Sin documento de identidad**: ningún perfil (Cliente, Propietario ni
  Administrador) solicita tipo ni número de documento. Se retira el maestro
  `identification_types` del alcance de esta rama.
- **NIT y tipo de persona del Propietario**: todo propietario, sea persona
  **natural** o **jurídica**, debe indicar su tipo de persona y su **NIT**
  (dato tributario, no documento de identidad). La razón social solo se pide
  a la persona jurídica.

> **Estado de la dependencia de Firebase (verificado 2026-10-27)**:
> integrada. `pubspec.yaml` incluye `firebase_core`, `firebase_auth` y
> `cloud_firestore`; existen `android/app/google-services.json`,
> `lib/firebase_options.dart` (FlutterFire) y `firebase.json`, y
> `lib/main.dart` inicializa Firebase. No existe
> `ios/Runner/GoogleService-Info.plist`. Auth0 fue retirado. El login usa
> `FirebaseAuthService` (el login quemado sigue disponible solo con
> `AUTH_USE_HARDCODED_AUTH_USERS=true`) y el perfil, rol y estado viven en
> Cloud Firestore (`users/{uid}`) protegidos por `firestore.rules`. Las
> decisiones están en `docs/decisions_log.md` (2026-10-27 y 2026-10-28).
> Al 2026-10-28 la base Firestore existe (`nam5`), las reglas están
> desplegadas y `.firebaserc` fija el proyecto `machuco`. Pendiente solo
> confirmar en la consola que Correo/contraseña está habilitado. Ver
> `docs/firebase.md`.

## Feature: Inicio de sesión

> Los escenarios se escriben contra Firebase Auth. Mientras Firebase no esté
> integrado, se cumplen con el login quemado temporal (ver "Acceso local
> temporal").

Scenario: Usuario inicia sesión con correo y contraseña (camino feliz)
Given un usuario registrado en la pantalla de login
When ingresa un correo válido y su contraseña
And presiona "Ingresar"
Then el sistema autentica al usuario con Firebase Auth
And obtiene su rol (Cliente, Propietario o Administrador)
And guarda el perfil básico del usuario en SQLite
And guarda el correo del usuario autenticado en SharedPreferences para compartirlo con el resto de la app
And navega a la ruta inicial correspondiente a su rol mediante `resolvePostLoginRoute`
But si la cuenta está en `pending_approval`, navega a "Cuenta en revisión" sin importar el rol

Scenario: Credenciales inválidas
Given un usuario en la pantalla de login
When ingresa un correo o una contraseña incorrectos y presiona "Ingresar"
Then el sistema muestra un mensaje genérico "Correo o contraseña incorrectos"
And no indica cuál de los dos campos falló
And el usuario permanece en la pantalla de login con el correo conservado

Scenario: Validación local de campos antes de enviar
Given un usuario en la pantalla de login
When deja el correo o la contraseña vacíos, o escribe un correo con formato inválido
And presiona "Ingresar"
Then el sistema no llama al servicio de autenticación
And señala junto a cada campo inválido el motivo del error

Scenario: Prevención de doble envío
Given un usuario que acaba de presionar "Ingresar"
When la autenticación todavía está en curso
Then el botón muestra un estado de carga y queda deshabilitado
And un segundo toque no genera una segunda petición

Scenario: Error de red al iniciar sesión
Given un usuario con credenciales válidas
When presiona "Ingresar" y la conexión falla antes de recibir respuesta
Then el sistema muestra un error de conexión comprensible con opción de reintentar
And no lo trata como credenciales inválidas

Scenario: Cuenta deshabilitada
Given un usuario cuya cuenta fue deshabilitada por un administrador
When intenta iniciar sesión con credenciales correctas
Then el sistema rechaza el acceso indicando que la cuenta está deshabilitada
And no crea sesión ni guarda el perfil en SQLite ni el correo de sesión en SharedPreferences

Scenario: Propietario rechazado intenta iniciar sesión
Given un propietario cuya solicitud fue rechazada por un administrador (estado `rejected`)
When inicia sesión con credenciales correctas
Then el sistema muestra que su solicitud fue rechazada y el motivo registrado
And no le da acceso a las vistas del propietario

Scenario: Recordar correo electrónico
Given un usuario que marca la opción "Recordar mi correo" e inicia sesión con éxito
When vuelve a abrir la pantalla de login en otro momento
Then el campo de correo aparece precargado con el último correo usado (leído de SharedPreferences)
But si desmarca la opción, el correo recordado se elimina de SharedPreferences

Scenario: Restauración automática de la sesión al abrir la app
Given un usuario que inició sesión previamente y no cerró sesión
When abre la aplicación
Then el sistema restaura la sesión con Firebase Auth
And carga desde SharedPreferences el correo del usuario autenticado
And navega directamente a la ruta de su rol sin mostrar el formulario de login
But si la sesión expiró o no puede restaurarse, borra el correo de sesión y muestra la pantalla de login

Scenario: Recuperación de contraseña
Given un usuario en la pantalla de login
When presiona "¿Olvidaste tu contraseña?", ingresa su correo y confirma
Then el sistema solicita a Firebase Auth el envío del correo de restablecimiento
And muestra un mensaje neutro: "Si el correo está registrado, recibirás instrucciones"
And no revela si el correo existe o no

Scenario: Cierre de sesión
Given un usuario autenticado en cualquier vista de su rol
When selecciona "Cerrar sesión"
Then el sistema cierra la sesión en Firebase Auth
And elimina el perfil del usuario guardado en SQLite, el correo de sesión y las preferencias de sesión
But conserva el correo recordado si el usuario tenía activa la opción "Recordar mi correo"
And conserva la caché de maestros (no es información personal)
And navega a la pantalla de login sin permitir volver atrás a una vista protegida

## Feature: Correo del usuario compartido (SharedPreferences)

Scenario: Guardar el correo al autenticarse
Given un usuario que inicia sesión, se registra o restaura su sesión con éxito
When el sistema confirma la autenticación
Then guarda su correo normalizado (sin espacios, en minúsculas) en SharedPreferences con la clave `current_user_email` del namespace `auth`

Scenario: Otra pantalla o funcionalidad consulta el correo
Given un usuario autenticado
When cualquier pantalla de otra funcionalidad (perfil, reservas, PQRS, pagos) necesita el correo del usuario
Then lo obtiene a través del método público de lectura que expone esta rama (p. ej. `AuthPreferences.loadCurrentUserEmail()`)
And ninguna vista lee SharedPreferences directamente
And si no hay correo guardado, recibe `null` y no un texto vacío ni una excepción

Scenario: Cargar el correo al abrir la app
Given un usuario con sesión válida y un correo guardado en SharedPreferences
When abre la aplicación
Then el correo queda disponible en memoria desde el arranque, antes de pintar la primera vista protegida

Scenario: El correo compartido no se usa para autorizar
Given cualquier funcionalidad que lea `current_user_email`
When toma una decisión de acceso o de datos del usuario
Then la autorización se valida con la sesión de Firebase Auth en el backend, no con el correo guardado localmente

## Feature: Acceso local temporal (usuarios de prueba) [Temporal]

> Firebase Auth ya está integrado; esta feature queda como herramienta de
> desarrollo y se elimina cuando el equipo ya no la necesite. No ampliarla
> con capacidades nuevas.

Scenario: [Temporal] La app usa usuarios de prueba en modo desarrollo
Given la aplicación ejecutándose con `--dart-define=AUTH_USE_HARDCODED_AUTH_USERS=true`
When se abre la pantalla de login
Then el `LoginController` usa el `HardcodedAuthService` en lugar de Firebase Auth
And la pantalla muestra un aviso visible "Modo desarrollo: autenticación local, no productiva"
And lista los usuarios de prueba disponibles por rol (cliente, propietario, administrador)

Scenario: [Temporal] Inicio de sesión con un usuario de prueba
Given la app en modo desarrollo
When el usuario ingresa las credenciales de un usuario de prueba
Then el sistema crea una sesión local con el rol de ese usuario
And guarda su correo en SharedPreferences igual que lo haría con Firebase
And navega a la ruta de ese rol igual que lo haría con Firebase

Scenario: [Temporal] [Pendiente] Creación de administradores y aprobación de propietarios en modo desarrollo
Given la app en modo desarrollo con un administrador de prueba autenticado
When crea un administrador o aprueba/rechaza un propietario
Then el cambio se aplica solo en memoria del servicio local
And el aviso de modo desarrollo indica que no hay validación real en backend

Scenario: [Temporal] El modo desarrollo no reemplaza la autorización real
Given la app en modo desarrollo
When un usuario navega por las vistas de su rol
Then ninguna regla de autorización depende de que el control esté oculto en la UI
And el aviso de modo desarrollo deja claro que no hay validación real de identidad

## Feature: Registro público de usuario (Cliente y Propietario)

> En la pantalla principal **solo se pueden registrar Clientes y
> Propietarios**. Los administradores se crean desde la vista del
> administrador (ver "Creación de administradores"). Los campos por rol son
> una propuesta de esta rama y deben validarse con producto (ver "Pendientes
> de validar").

### Matriz de registro por rol

| Aspecto | Cliente (registro público) | Propietario (registro público) | Administrador (lo crea otro administrador) |
| --- | --- | --- | --- |
| Datos comunes (nombres, apellidos, indicativo y celular, correo, contraseña, confirmación) | Sí | Sí | Sí (sin contraseña, ver feature de creación) |
| Tipo y número de documento | **No se solicita** | **No se solicita** | **No se solicita** |
| Campos propios | Fecha de nacimiento | Tipo de persona (natural/jurídica), NIT y plan de suscripción de interés (obligatorios); si es jurídica, además razón social | — |
| Regla clave | Debe ser mayor de 18 años | Su cuenta debe aprobarla un administrador | Solo un administrador autenticado puede crearlo |
| Estado inicial de la cuenta | `active` | `pending_approval` | `active` |
| Destino tras el registro | Ruta del cliente | Pantalla "Cuenta en revisión" | (No aplica: el creador permanece en su vista) |
| Registro con Google o GitHub ([Futuro], no se implementa aún) | Sí | Sí, pero luego debe completar los campos propios | No |

Scenario: Visitante elige el rol antes de diligenciar el formulario
Given un visitante en la pestaña "Registrarse"
When ve el selector de tipo de perfil
Then solo se ofrecen las opciones Cliente y Propietario (Administrador no aparece)
When selecciona un tipo de perfil
Then el sistema muestra el bloque de datos comunes más los campos propios de ese rol
And ningún perfil muestra campos de tipo ni número de documento
When el visitante cambia de rol con datos ya escritos
Then el sistema conserva los datos comunes
And descarta los campos propios del rol anterior

Scenario: Cliente se registra (camino feliz)
Given un visitante que eligió el perfil Cliente
When diligencia nombres, apellidos, indicativo y celular, correo, contraseña, confirmación y fecha de nacimiento
And presiona "Crear cuenta"
Then el sistema no le solicita tipo ni número de documento
And crea la cuenta en Firebase Auth con rol `client` y estado `active`
And guarda el perfil con el id del indicativo telefónico (no el texto mostrado)
And guarda en SharedPreferences el correo del usuario y el indicativo usado como último indicativo seleccionado
And navega a la ruta inicial del cliente

Scenario: Cliente menor de edad
Given un visitante que eligió el perfil Cliente
When ingresa una fecha de nacimiento que corresponde a una persona menor de 18 años
Then el sistema rechaza el registro e indica que debe ser mayor de edad
And no crea la cuenta

Scenario: Propietario persona natural se registra (camino feliz)
Given un visitante que eligió el perfil Propietario y el tipo de persona "Natural"
When el sistema muestra el campo NIT como obligatorio
And el visitante diligencia los datos comunes y su NIT
And presiona "Crear cuenta"
Then el sistema no le solicita tipo ni número de documento ni razón social
And crea la cuenta con rol `owner`, tipo de persona natural, su NIT y estado `pending_approval`
And la solicitud aparece en "Solicitudes de propietarios" de los administradores
And navega a la pantalla "Cuenta en revisión", que explica que un administrador debe aprobarla

Scenario: Propietario persona jurídica se registra
Given un visitante que eligió el perfil Propietario y el tipo de persona "Jurídica"
When el sistema muestra los campos razón social y NIT como obligatorios
And el visitante los diligencia junto con los datos comunes del representante (sin documento del representante)
And presiona "Crear cuenta"
Then el sistema crea la cuenta con rol `owner`, tipo de persona jurídica, razón social, NIT y estado `pending_approval`
But si falta la razón social o el NIT tiene un formato inválido, no envía el formulario y señala el campo

Scenario: Propietario sin tipo de persona o sin NIT
Given un visitante que eligió el perfil Propietario
When intenta crear la cuenta sin elegir el tipo de persona o sin diligenciar el NIT
Then el sistema no envía el formulario
And señala que el tipo de persona y el NIT son obligatorios para todo propietario
When cambia el tipo de persona de "Jurídica" a "Natural"
Then conserva el NIT escrito y oculta y descarta la razón social

Scenario: Propietario pendiente de aprobación intenta iniciar sesión
Given un propietario registrado cuya cuenta sigue en estado `pending_approval`
When inicia sesión con credenciales correctas
Then el sistema lo lleva a la pantalla "Cuenta en revisión"
And no le da acceso a las vistas de gestión de moteles hasta que un administrador apruebe la cuenta

Scenario: Intento de registrarse como administrador desde el registro público
Given cualquier registro público
When la petición llega con `role: admin` (p. ej. un cliente manipulado)
Then el backend la rechaza y no crea ninguna cuenta, ni siquiera con otro rol
And el rol y el estado inicial los asigna y valida siempre el backend según las reglas del rol

Scenario: Términos y condiciones (temporal)
Given un visitante en el formulario de registro
When ve el final del formulario, antes de "Crear cuenta"
Then encuentra un botón o enlace "Términos y condiciones"
When lo presiona
Then se abre un AppBottomSheet con un texto provisional "Contenido de términos y condiciones pendiente"
And cerrar el panel lo devuelve al formulario con los datos intactos
And por ahora su lectura o aceptación no bloquea el registro
But el componente queda preparado para, más adelante, mostrar el documento vigente y exigir una casilla de aceptación

Scenario: Validación del número de celular según el país
Given un visitante en el formulario de registro con un indicativo seleccionado
When escribe un número de celular con longitud fuera del rango definido por ese país en el maestro
Then el sistema señala que el número no es válido para el país seleccionado
And no permite enviar el formulario

Scenario: Ningún formulario solicita documento de identidad
Given un visitante en el registro público o un administrador en "Crear administrador"
When revisa el formulario de cualquier perfil
Then no encuentra campos de tipo ni número de documento
And la petición al backend no incluye esos datos

Scenario: Campos obligatorios del registro
Given un visitante en el formulario de registro con un rol elegido
When intenta crear la cuenta sin alguno de los datos comunes o sin un campo propio obligatorio de ese rol
Then el sistema no envía el formulario
And señala cada campo obligatorio faltante

Scenario: Contraseñas no coinciden o son débiles
Given un visitante en el formulario de registro
When la confirmación no coincide con la contraseña, o la contraseña tiene menos de 8 caracteres (en desarrollo no se exigen letras ni números; endurecer antes de producción)
Then el sistema muestra el error junto al campo correspondiente
And no envía el formulario

Scenario: Correo ya registrado
Given un visitante que intenta registrarse con un correo que ya tiene cuenta
When presiona "Crear cuenta"
Then el sistema informa que el correo ya está en uso
And ofrece ir a "Iniciar sesión" o "¿Olvidaste tu contraseña?"

## Feature: Consulta de planes de suscripción para propietarios (Supabase + SQLite)

> Esta rama solo **consulta** los planes posibles y registra el plan de
> interés del propietario. El cobro, la activación y la gestión de la
> suscripción pertenecen a la rama de suscripciones
> (`lib/database/repository/suscripcion/`).

Scenario: El propietario consulta los planes disponibles al registrarse
Given un visitante que eligió el perfil Propietario en el formulario de registro
When se muestra el bloque propio del propietario
Then el sistema consulta los planes activos del maestro `subscription_plans`
And los muestra ordenados por `sort_order` con nombre, descripción, precio en COP, periodicidad, número máximo de moteles y características
And el visitante debe elegir un plan de interés antes de "Crear cuenta"

Scenario: El plan elegido se guarda con la solicitud del propietario
Given un visitante Propietario que eligió un plan y diligenció el formulario válido
When presiona "Crear cuenta"
Then la cuenta se crea en `pending_approval` con el id del plan elegido (no el nombre mostrado)
And el plan aparece en el detalle de la solicitud que ve el administrador
And la suscripción no se activa ni se cobra hasta que la cuenta sea aprobada y la rama de suscripciones lo procese

Scenario: Uso de la caché local de planes
Given un dispositivo con los planes ya guardados en SQLite hace menos de 24 horas
When el visitante elige el perfil Propietario
Then el sistema muestra los planes desde SQLite sin esperar a la red
And solo consulta Supabase cuando se fuerza el refresco o la caché venció

Scenario: Sin conexión y sin caché de planes
Given un dispositivo sin caché de planes y sin conexión
When el visitante elige el perfil Propietario
Then el bloque de planes muestra un estado de error con opción de reintentar
And el botón "Crear cuenta" permanece deshabilitado para Propietario
But el registro de Cliente y el inicio de sesión siguen funcionando

Scenario: Sin planes activos
Given el maestro `subscription_plans` sin registros activos
When el visitante elige el perfil Propietario
Then el sistema muestra un estado vacío "No hay planes disponibles por ahora"
And no permite crear la cuenta de propietario

Scenario: Un plan se desactiva
Given un plan marcado como inactivo en Supabase
When el sistema refresca los planes
Then el plan deja de mostrarse en el registro
But los propietarios que ya lo eligieron conservan la referencia en su solicitud

Scenario: El plan elegido no se usa para autorizar ni cobrar desde la app
Given una petición de registro con un `plan_id` manipulado o inexistente
When llega al backend
Then el backend valida que el plan exista y esté activo, y si no, rechaza el registro
And el precio nunca se toma del valor enviado por la app

## Feature: Ingreso con proveedores externos (Google/Gmail y GitHub) [Futuro]

> **Solo definición, no implementación.** Estos escenarios se implementarán
> más adelante con los proveedores de Firebase Auth (`GoogleAuthProvider` y
> `GithubAuthProvider`) y **en cooperación con otras ramas** (configuración
> del proyecto de Firebase, OAuth App de GitHub, SHA-1/SHA-256 de Android,
> URL schemes de iOS). En esta rama **no** se agregan dependencias
> (`google_sign_in` u otras), ni lógica de controller, ni servicios para
> ellos. Mientras tanto solo aplica el escenario "Proveedores externos aún no
> disponibles".

Scenario: Proveedores externos aún no disponibles
Given la aplicación sin los proveedores externos habilitados
When el usuario ve la pantalla de login o de registro
Then los botones "Continuar con Google" y "Continuar con GitHub" no se muestran, o se muestran deshabilitados con la etiqueta "Próximamente"
And presionarlos no lanza una excepción ni bloquea el formulario de correo y contraseña

Scenario: [Futuro] Inicio de sesión con Google (Gmail)
Given un usuario con cuenta existente vinculada a Google y Firebase Auth configurado con el proveedor de Google
When presiona "Continuar con Google" y completa el flujo del proveedor
Then el sistema autentica al usuario con Firebase Auth
And obtiene su rol y estado de cuenta desde el backend
And guarda su correo en SharedPreferences y navega a la ruta de su rol mediante `resolvePostLoginRoute`
But si el usuario cancela el flujo, permanece en el login sin mostrar error

Scenario: [Futuro] Inicio de sesión con GitHub
Given un usuario con cuenta existente vinculada a GitHub y Firebase Auth configurado con el proveedor de GitHub
When presiona "Continuar con GitHub" y autoriza la aplicación
Then el sistema autentica al usuario con Firebase Auth
And obtiene su rol y estado de cuenta desde el backend
And guarda su correo en SharedPreferences y navega a la ruta de su rol
But si GitHub no entrega un correo verificado, el sistema no crea sesión e informa que debe usar una cuenta con correo público o verificado

Scenario: [Futuro] Registro con un proveedor externo según el rol
Given un visitante en el formulario de registro que eligió un tipo de perfil
When elige "Continuar con Google" o "Continuar con GitHub" y completa el flujo
Then para Cliente, el sistema pide completar los datos que el proveedor no entrega (nombres y apellidos si faltan, indicativo y celular, fecha de nacimiento) antes de crear el perfil y navegar
And para Propietario, pide completar indicativo y celular, tipo de persona, NIT y, si es jurídica, razón social, y la cuenta queda en `pending_approval`
And el rol y el estado inicial los asigna y valida el backend, igual que en el registro con correo
And nunca se crea una cuenta `admin` por este medio

Scenario: [Futuro] Correo ya registrado con otro método
Given un visitante cuyo correo ya tiene cuenta con correo y contraseña u otro proveedor
When intenta ingresar con Google o GitHub usando ese mismo correo
Then el sistema no crea una cuenta duplicada
And le indica que ya existe una cuenta con ese correo y que inicie sesión con el método original para vincular el proveedor

Scenario: [Futuro] Cuenta deshabilitada, pendiente o rechazada con proveedor externo
Given un usuario cuya cuenta está `disabled`, `pending_approval` o `rejected`
When inicia sesión con Google o GitHub
Then el sistema aplica las mismas reglas que en el inicio de sesión con correo y contraseña

## Feature: Validación de formato de los datos del formulario

> Aplica al login, al registro público y al formulario de creación de
> administradores. La validación vive en el controller (o en validadores de
> `lib/controllers/auth/`), no en la vista, y se repite en el backend.

### Reglas de formato

| Campo | Regla |
| --- | --- |
| Nombres / apellidos | Solo letras (con tildes y ñ), espacios, guion y apóstrofo; 2 a 50 caracteres; sin espacios dobles |
| Correo | Formato `usuario@dominio.ext`, máx. 254 caracteres; se recortan espacios y se guarda en minúsculas |
| Celular | Solo dígitos; longitud entre `phone_min_length` y `phone_max_length` del país |
| NIT del propietario (natural y jurídica, obligatorio) | Solo dígitos, guion opcional y dígito de verificación válido. Jurídica: 9 dígitos + DV (p. ej. `900123456-7`). Natural: número base de 6 a 10 dígitos + DV (p. ej. `1020304050-3`) |
| Razón social | 2 a 120 caracteres; letras, números, espacios y `. , & -` |
| Fecha de nacimiento | Fecha real, no futura, edad ≥ 18 años |
| Contraseña | Mínimo 8 caracteres en desarrollo (sin reglas de complejidad). Propuesta para producción: 8 a 64 caracteres, al menos una letra y un número |

Scenario: Formato inválido en un campo
Given un usuario diligenciando cualquier formulario de esta rama
When escribe un valor que no cumple la regla de formato del campo
And sale del campo o presiona el botón de envío
Then el sistema muestra junto al campo un mensaje en español que explica el formato esperado
And el formulario no se envía mientras haya algún campo con formato inválido

Scenario: Normalización antes de validar
Given un usuario que escribe un dato con espacios al inicio o al final, o un correo con mayúsculas
When el sistema valida el formulario
Then recorta los espacios y normaliza el correo a minúsculas antes de validar y enviar
And no muestra error por esas diferencias

Scenario: Campos con caracteres no permitidos
Given un usuario que pega texto con caracteres de control, emojis o símbolos no permitidos en nombres, celular o NIT
When el sistema valida el campo
Then lo marca como inválido indicando qué caracteres se admiten
And no los envía al backend

## Feature: Protección contra inyección SQL

Scenario: Entradas con código SQL en el login
Given un usuario en la pantalla de login
When escribe en el correo o en la contraseña un valor como `' OR '1'='1' --` o `admin'; DROP TABLE users; --`
And presiona "Ingresar"
Then el sistema trata el valor como texto literal
And el correo falla la validación de formato o la autenticación con el mensaje genérico "Correo o contraseña incorrectos"
And no se ejecuta ninguna instrucción SQL adicional ni se altera ningún dato

Scenario: Entradas con código SQL en el registro y en la creación de administradores
Given un usuario en un formulario de registro o de creación de administrador
When escribe código SQL en nombres, apellidos, razón social, NIT o cualquier otro campo
Then la validación de formato lo rechaza en los campos con formato restringido
And en los campos de texto libre el valor se guarda como texto literal sin ejecutarse

Scenario: Consultas parametrizadas en SQLite y Supabase
Given cualquier consulta de esta rama a SQLite (Floor) o a Supabase (REST)
When incluye un valor ingresado por el usuario o recibido de la red
Then el valor se pasa como parámetro enlazado (`:param` en Floor) o como filtro codificado en la URL de PostgREST
And nunca se arma una consulta concatenando texto con datos del usuario
And las tablas de Supabase mantienen RLS, de modo que una petición manipulada no puede leer ni escribir fuera de lo permitido

Scenario: Búsqueda en el selector de indicativo
Given un visitante que escribe `%`, `'`, `;` o `--` en el buscador de países
When se filtra la lista
Then el filtro se aplica en memoria o con parámetros enlazados
And la app no falla ni muestra resultados inesperados

## Feature: Creación de administradores (vista del administrador) [Pendiente]

> No implementada al 2026-10-28: los administradores se crean a mano en la
> consola de Firebase (`users/{uid}` con `role: admin`).

> Solo un administrador autenticado puede crear otro administrador. La
> creación ocurre en el **backend** (p. ej. una función con Firebase Admin
> SDK), porque crear un usuario con el SDK cliente de Firebase cerraría la
> sesión del administrador creador e impediría validar el rol del lado del
> servidor.

Scenario: El administrador accede a la vista "Administradores"
Given un administrador autenticado
When abre su perfil o menú y selecciona "Administradores"
Then el sistema muestra la lista de administradores existentes (nombre, correo y estado)
And un botón "Crear administrador"

Scenario: Crear un administrador (camino feliz)
Given un administrador en la vista "Administradores"
When presiona "Crear administrador"
And diligencia nombres, apellidos, indicativo y celular y correo con formato válido (sin tipo ni número de documento)
And presiona "Crear"
Then el backend verifica que quien hace la petición tiene rol `admin` y cuenta `active`
And crea la cuenta con rol `admin` y estado `active`
And envía al nuevo administrador un correo para definir su contraseña (el creador nunca conoce ni define la contraseña)
And registra qué administrador lo creó y cuándo
And el administrador creador permanece en su sesión y ve al nuevo administrador en la lista con un mensaje de confirmación

Scenario: Correo ya registrado al crear un administrador
Given un administrador en el formulario "Crear administrador"
When ingresa un correo que ya pertenece a otra cuenta
Then el sistema informa que el correo ya está en uso
And no crea ni modifica ninguna cuenta (no convierte en administrador a un cliente o propietario existente)

Scenario: Datos inválidos al crear un administrador
Given un administrador en el formulario "Crear administrador"
When deja campos obligatorios vacíos o con formato inválido
Then el sistema no envía el formulario y señala cada campo

Scenario: Un usuario que no es administrador intenta crear un administrador
Given un cliente o propietario autenticado, o una petición manipulada
When intenta acceder a la ruta de "Administradores" o llama directamente a la operación de creación
Then la app no muestra la vista (redirige a la ruta de su rol)
And el backend rechaza la petición aunque la app haya sido modificada

Scenario: Prevención de doble envío al crear un administrador
Given un administrador que acaba de presionar "Crear"
When la creación todavía está en curso
Then el botón muestra estado de carga y queda deshabilitado
And un segundo toque no crea una segunda cuenta

## Feature: Solicitudes de aprobación de propietarios (vista del administrador) [Pendiente]

> No implementada al 2026-10-28. Las reglas de Firestore ya permiten que un
> admin cambie `accountStatus`; falta la interfaz.

Scenario: El administrador consulta las solicitudes pendientes
Given un administrador autenticado
When abre su perfil o menú y selecciona "Solicitudes de propietarios"
Then el sistema muestra la lista de propietarios en estado `pending_approval`, de la más antigua a la más reciente
And cada elemento muestra nombre o razón social, tipo de persona, correo y fecha de la solicitud
And el acceso muestra un contador con el número de solicitudes pendientes

Scenario: Sin solicitudes pendientes
Given un administrador en "Solicitudes de propietarios"
When no hay propietarios en estado `pending_approval`
Then el sistema muestra un estado vacío "No hay solicitudes pendientes"

Scenario: Ver el detalle de una solicitud
Given un administrador en la lista de solicitudes
When selecciona una solicitud
Then el sistema muestra los datos del registro: nombres, apellidos, celular con indicativo, correo, tipo de persona, NIT, plan de suscripción de interés y, si es jurídica, razón social
And los botones "Aprobar" y "Rechazar"

Scenario: Aprobar una solicitud
Given un administrador en el detalle de una solicitud pendiente
When presiona "Aprobar" y confirma
Then el backend verifica que quien aprueba es un administrador activo
And cambia la cuenta del propietario a estado `active`
And registra qué administrador la aprobó y cuándo
And la solicitud desaparece de la lista de pendientes
And en su próximo inicio de sesión el propietario accede a su ruta inicial en lugar de "Cuenta en revisión"

Scenario: Rechazar una solicitud
Given un administrador en el detalle de una solicitud pendiente
When presiona "Rechazar"
Then el sistema exige un motivo de rechazo (obligatorio, 10 a 300 caracteres)
And al confirmar, cambia la cuenta del propietario a estado `rejected` y guarda el motivo, el administrador y la fecha
And la solicitud desaparece de la lista de pendientes

Scenario: Solicitud ya resuelta por otro administrador
Given dos administradores con la misma solicitud abierta
When uno la aprueba o rechaza y luego el otro intenta resolverla
Then el backend rechaza la segunda acción porque la cuenta ya no está en `pending_approval`
And la app informa que la solicitud ya fue atendida y refresca la lista

Scenario: Un usuario que no es administrador intenta ver las solicitudes
Given un cliente o propietario autenticado, o una petición manipulada
When intenta acceder a "Solicitudes de propietarios" o aprobar una cuenta
Then la app no muestra la vista
And el backend rechaza la consulta y la acción

Scenario: Error de red al cargar o resolver solicitudes
Given un administrador en "Solicitudes de propietarios"
When la conexión falla al cargar la lista o al aprobar/rechazar
Then el sistema muestra un error comprensible con opción de reintentar
And no cambia el estado mostrado de la solicitud hasta recibir confirmación del backend

## Feature: Maestro de indicativo telefónico (Supabase + SQLite)

Scenario: Primera carga de maestros desde Supabase
Given un dispositivo sin caché local de maestros y con conexión
When el visitante abre la pestaña "Registrarse"
Then el sistema consulta en Supabase los indicativos telefónicos activos
And los guarda en SQLite
And los muestra ordenados por `sort_order`

Scenario: Uso de la caché local en cargas posteriores
Given un dispositivo con los maestros ya guardados en SQLite
When el visitante abre el formulario de registro
Then el sistema muestra los maestros desde SQLite sin esperar a la red
And solo consulta Supabase cuando se fuerza el refresco o la caché supera su vigencia (24 horas, guardada en SharedPreferences)

Scenario: Sin conexión y sin caché
Given un dispositivo sin caché de maestros y sin conexión
When el visitante abre el formulario de registro
Then el selector de indicativo muestra un estado de error con opción de reintentar
And el botón "Crear cuenta" permanece deshabilitado
But la pestaña "Iniciar sesión" sigue funcionando con normalidad

Scenario: Supabase no configurado
Given la app ejecutándose sin `SUPABASE_URL` / `SUPABASE_ANON_KEY`
When se cargan los maestros
Then el sistema usa la caché de SQLite si existe
And si no existe, usa una semilla local mínima de desarrollo (Colombia +57)
And la semilla queda marcada como datos de desarrollo y se reemplaza en cuanto Supabase responda

Scenario: Solo se ofrecen registros activos
Given un registro de un maestro marcado como inactivo en Supabase
When el sistema refresca los maestros
Then ese registro deja de mostrarse en los selectores
And se elimina o marca como inactivo en la caché de SQLite
But los usuarios ya registrados con ese valor conservan la referencia en su perfil

Scenario: Indicativo preseleccionado
Given un visitante que abre el formulario de registro
When se cargan los indicativos
Then el sistema preselecciona el último indicativo usado (SharedPreferences)
And si no hay ninguno guardado, preselecciona Colombia (+57)

Scenario: Búsqueda de país en el selector de indicativo
Given un visitante que abre el selector de indicativo
When escribe parte del nombre del país, su código ISO o el indicativo
Then la lista se filtra mostrando solo las coincidencias
And si no hay coincidencias muestra un estado vacío

## Maestros en Supabase

### Ya definidos en esta rama

`country_phone_codes` (indicativo telefónico por país)

| Columna | Tipo | Notas |
| --- | --- | --- |
| `id` | `int` PK | |
| `iso_code` | `text` único | ISO 3166-1 alfa-2, p. ej. `CO` |
| `country_name` | `text` | Texto visible en español |
| `dial_code` | `text` | Con `+`, p. ej. `+57` |
| `flag_emoji` | `text` nullable | Opcional para la UI |
| `phone_min_length` | `int` | Validación del celular |
| `phone_max_length` | `int` | Validación del celular |
| `is_active` | `bool` | |
| `sort_order` | `int` | Colombia primero |

`subscription_plans` (planes de suscripción para propietarios)

La tabla **ya existe** en Supabase y la rama de suscripciones la consulta
hoy con `select=id,name`. Esta rama la **amplía** con las columnas
siguientes, en coordinación con esa rama (agregar columnas no rompe su
consulta actual):

| Columna | Tipo | Notas |
| --- | --- | --- |
| `id` | `int` PK | Existente |
| `name` | `text` | Existente; texto visible en español |
| `description` | `text` nullable | Resumen del plan |
| `price` | `numeric(12,2)` | Precio de referencia; el backend valida el cobro |
| `currency` | `text` | `COP` por defecto |
| `billing_period` | `text` | `monthly` / `yearly` |
| `max_motels` | `int` nullable | Límite de moteles del plan |
| `features` | `text[]` | Características visibles |
| `is_active` | `bool` | |
| `sort_order` | `int` | |

> El maestro `identification_types` (tipo de identificación) se retiró del
> alcance: ningún perfil solicita tipo ni número de documento.

Las tablas son de **solo lectura** para la app: política RLS que permita
`select` con la clave pública y ninguna escritura desde el cliente. La
administración de los registros se hace desde Supabase. El detalle de
conexión (URL, clave, SQL y recorrido) está en el documento "MACHUCO —
Conexión con Firebase y Supabase".

### Maestros adicionales sugeridos (no son criterio de aceptación)

Validar con el equipo antes de comprometerlos en el alcance de esta rama:

- **Versiones de términos y condiciones / política de tratamiento de datos**
  (`legal_documents`): versión, URL y fecha de vigencia, para registrar qué
  versión aceptó cada usuario al registrarse (exigido por la Ley 1581 de 2012
  de habeas data en Colombia). Es lo que reemplazaría el contenido provisional
  del botón "Términos y condiciones".
- **Motivos de rechazo de propietarios** (`owner_rejection_reasons`): lista
  de motivos frecuentes para el rechazo, además del texto libre.
- **Tipos de perfil** (`user_roles`): título, descripción y campos propios
  de cada rol en el registro, en lugar de tenerlos fijos en la vista.
- **Tipo de persona** (`person_types`: natural / jurídica): el registro del
  propietario ya lo necesita. Mientras no exista el maestro, se maneja como
  un enum local `PersonType` en `lib/models/auth/`.
- **Países → departamentos → ciudades** (`countries`, `regions`,
  `cities`): ubicación del usuario y base reutilizable para direcciones de
  moteles.
- **Política de contraseñas** (`password_policies`): longitud mínima y
  reglas, para no fijarlas en el código.
- **Proveedores de inicio de sesión habilitados** (`auth_providers`: correo,
  Google, GitHub): permite encender o apagar "Continuar con Google" y
  "Continuar con GitHub" sin publicar una nueva versión.
- **Motivos de bloqueo o desactivación de cuenta** (`account_block_reasons`):
  mensaje claro al usuario cuando su cuenta está deshabilitada.
- **Género o tratamiento** (`genders`), solo si producto lo necesita.

## Alcance técnico

- **Directorios de trabajo**:
  - Vistas: `lib/views/login/` (`login_page.dart`, `logout_navigation.dart`), `lib/views/register/` y `lib/views/admin_access/` (`administrators_page.dart`, `create_admin_page.dart`, `owner_approvals_page.dart`, `owner_approval_detail_page.dart`).
  - Controllers: `lib/controllers/auth/login_controller.dart`. Si la carga de maestros crece, separarla en `lib/controllers/auth/auth_catalog_controller.dart`. Las vistas del administrador usan `lib/controllers/auth/admin_access_controller.dart` (creación de administradores y aprobación de propietarios). Validadores de formato en `lib/controllers/auth/validators/`.
  - Rutas nuevas en `lib/routes/routes.dart` (solo rol administrador): `adminAdministrators` (`/auth/admin/administrators`), `adminCreateAdministrator` (`/auth/admin/administrators/new`), `adminOwnerApprovals` (`/auth/admin/owner-approvals`) y `adminOwnerApprovalDetail` (`/auth/admin/owner-approvals/detail`). Se enlazan desde el perfil o menú del administrador.
  - Modelos: `lib/models/auth/`.
    - `registered_user.dart`: agregar `firstNames`, `lastNames`, `phoneCountryCodeId` y `accountStatus`. No incluir campos de tipo ni número de documento.
    - Datos propios por rol: `birthDate` (cliente); `personType` y `nit` obligatorios y `companyName` solo para persona jurídica (propietario). Modelarlos como campos opcionales validados por rol o como un objeto de detalle por rol; no crear tres modelos de usuario paralelos.
    - Nuevos: `country_phone_code.dart`, `person_type.dart` (enum), `account_status.dart` (enum: `active`, `pending_approval`, `rejected`, `disabled`) y `owner_approval_request.dart` (solicitud con fecha, y al resolverse: administrador, fecha y motivo de rechazo). Al 2026-10-28 existen `country_phone_code.dart`, `account_status.dart` y `user_profile.dart`; `person_type.dart` y `owner_approval_request.dart` siguen pendientes.
    - Se mantiene `RegisteredUserRole { admin, client, owner }` como único enum de rol.
  - Registro por rol: la validación específica de cada rol vive en el controller (o en un validador por rol en `lib/controllers/auth/`), no en la vista. La vista solo decide qué bloque de campos mostrar según el rol elegido.
  - Servicios de autenticación: `lib/service/auth/`.
    - Destino final: `firebase_auth_service.dart` como **único** proveedor. **Hecho (2026-10-27):** decisión documentada y `firebase_core`, `firebase_auth` y `cloud_firestore` agregados.
    - Transitorio: el contrato `AuthService` / `AuthSession` / `AuthFailure` (en `auth_service.dart`) y `hardcoded_auth_service.dart` se mantienen solo mientras exista el login quemado. No se amplía el contrato con capacidades nuevas; al integrar Firebase se retiran junto con el selector de implementación (`auth_service_factory.dart`, si se llegó a crear).
    - La creación de administradores y la aprobación/rechazo de propietarios se exponen como operaciones del backend; la app solo las invoca a través de un repositorio (p. ej. `lib/database/repository/auth/admin_access_repository.dart`, aún no creado).
    - Limpieza (no es un escenario): el código heredado de un proveedor anterior (`auth0_auth_service.dart`, `auth0_config.dart`, la dependencia `auth0_flutter` y sus referencias en `login_controller.dart`, `login_page.dart`, `logout_navigation.dart`, `backend_registered_user_directory.dart`, `hardcoded_auth_service.dart` y las pruebas) se retira al integrar Firebase. Antes de borrarlo, verificar con `grep` que ninguna otra rama lo importa. No se escriben escenarios ni se amplía ese código. **Hecho (2026-10-27):** `FirebaseAuthService` reemplaza a Auth0; el contrato quedó en `auth_service.dart` y los flags en `auth_config.dart`.
  - Maestros: `lib/database/repository/auth/` — `auth_catalog_dao.dart` (tabla `country_phone_codes` en SQLite; `subscription_plan_options` sigue pendiente) y `auth_catalog_repository.dart` (REST a Supabase + caché), siguiendo el patrón de `lib/database/repository/room/room_service_repository.dart`. Modelo nuevo: `lib/models/auth/subscription_plan_option.dart` (no reutilizar `SubscriptionPlan` de la rama de suscripciones, que solo tiene `id` y `name`, ni su tabla `subscriptions` de SQLite).
  - Almacenamiento en Firebase: el perfil del usuario y las solicitudes de propietarios se leen y escriben a través de un repositorio (p. ej. `lib/database/repository/auth/user_profile_repository.dart`), nunca desde la vista.
  - Preferencias: `SharedPreferencesLocalService` con `namespace: 'auth'` (contrato en `lib/service/storage/local_preferences_service.dart`). El acceso compartido al correo se expone con una clase pequeña (p. ej. `lib/service/auth/auth_preferences.dart`) que otras ramas consumen sin conocer las claves.
- **Claves de SharedPreferences (namespace `auth`)**: `current_user_email` (string; correo del usuario autenticado, compartido con otras funcionalidades), `remember_email` (bool), `remembered_email` (string), `last_country_code_id` (int), `last_auth_tab` (string), `catalogs_synced_at` (string ISO-8601). **Nunca** guardar contraseñas, tokens ni el NIT en SharedPreferences. La persistencia del token la maneja el SDK de Firebase; en el login quemado la sesión es solo en memoria.
- **SQLite**: las tablas nuevas se registran en `lib/database/app_database.dart` con una migración nueva (versión actual: 11; `country_phone_codes` se crea en la 10 → 11 y en instalaciones nuevas. La caché de planes, si se implementa, irá en una migración nueva). Es un archivo compartido con otras ramas (`room`, `suscripcion`, `motel`, `client`, pagos): coordinar el número de versión antes de hacer merge para no chocar migraciones.
- **Configuración de Supabase**: reutilizar `SUPABASE_URL` y `SUPABASE_ANON_KEY` vía `--dart-define`. Las ramas de suscripciones y notificaciones leen `SUPABASE_PUBLISHABLE_KEY`; proponer al equipo un solo nombre. `SupabaseRoomConfig` es específico de habitaciones; si se necesita una configuración común, proponer al equipo una sola clase compartida en lugar de crear otra copia.
- **Dependencias de entrada**: rutas por rol de `lib/routes/routes.dart` (`clientMotels`, `ownerMotels`, `ownerManagement`); componentes del sistema de diseño (`AppTextField`, `AppButton`, `AppCard`, `AppBottomSheet`).
- **Dependencias de salida**: todas las vistas protegidas dependen de la sesión que expone `LoginController` (usuario y rol). `logout_navigation.dart` es consumido por otras ramas para cerrar sesión: no cambiar su firma sin avisar. El lector del correo compartido (`AuthPreferences` o equivalente) también es una API pública para otras ramas.
- **Fuera de alcance**:
  - Las vistas de destino de cada rol (pertenecen a otras ramas), salvo las vistas "Administradores" y "Solicitudes de propietarios" del administrador.
  - La gestión general de usuarios (activar/desactivar cuentas existentes, editar o eliminar administradores).
  - El contenido real de los términos y condiciones (solo se deja el botón con contenido provisional).
  - El CRUD de los maestros (se administran directamente en Supabase).
  - El cobro, la activación y la gestión de la suscripción del propietario (rama de suscripciones); aquí solo se consultan los planes y se registra el plan de interés.
  - Inicio de sesión por SMS/OTP con el número de celular.
  - La implementación del login y registro con Google/Gmail y GitHub: aquí solo se definen sus escenarios; se implementa más adelante en cooperación con otras ramas.
  - Verificación de correo obligatoria antes del primer ingreso (queda como mejora posible con Firebase).
- **Reglas de seguridad**:
  - La autorización por rol se valida en el backend. El rol enviado por la app es solo una solicitud: la creación de administradores, la aprobación de propietarios, la mayoría de edad del cliente y el estado inicial del propietario se verifican del lado del servidor.
  - El registro público nunca crea cuentas `admin`.
  - Toda consulta a SQLite o Supabase usa parámetros enlazados; nunca se concatenan datos del usuario en una consulta.
  - Los mensajes de error de login y de recuperación de contraseña no deben revelar si un correo existe.
  - El correo guardado en SharedPreferences sirve para mostrar y precargar datos, no para autorizar.
  - Ninguna vista consulta Supabase, Firebase, SQLite ni SharedPreferences directamente: siempre a través del controller y del repositorio o servicio.

## Pendientes de validar con producto

Estas reglas son una propuesta de esta rama. Se implementan así mientras
nadie las corrija, pero deben confirmarse:

- Los campos propios de cada rol (fecha de nacimiento del cliente; tipo de
  persona, NIT y razón social del propietario).
- La edad mínima de 18 años para clientes.
- La longitud del número base del NIT de persona natural (propuesta: 6 a 10
  dígitos más dígito de verificación).
- Si el propietario elige el plan de suscripción al registrarse (propuesta,
  obligatorio) o después de ser aprobado, y cuáles son los planes reales.
- ~~Si el almacenamiento en Firebase es Cloud Firestore, Cloud Storage o ambos,
  y si el rol se guarda como custom claim (requiere Cloud Functions) o en un
  documento de Firestore.~~ **Resuelto (2026-10-27):** Cloud Firestore; el rol
  y el estado se guardan en el documento `users/{uid}`. Cloud Storage
  (archivos) sigue sin decidir.
- Si el administrador creado define su contraseña mediante correo de
  restablecimiento (propuesta) o con una contraseña temporal.
- Si un propietario rechazado puede corregir sus datos y volver a enviar la
  solicitud, o debe registrarse de nuevo.
- Si "Términos y condiciones" pasará a requerir una casilla de aceptación
  obligatoria y qué documento mostrará.

## Notas para el agente

- **Contexto histórico**: esta rama construyó antes el módulo de bookings
  (Cliente, Propietario y Administrador en `lib/views/booking/`,
  `lib/controllers/booking/`, `lib/models/booking/`). Ese trabajo ya no es
  responsabilidad de esta rama; no refactorizarlo como parte del login.
- El login actual ya tiene la base: pestañas de login y registro, selector
  de tipo de perfil, avisos de modo desarrollo y usuarios de prueba, y una
  tarjeta de sesión activa. **Hecho (2026-10-28):** se retiraron los avisos
  del proveedor anterior, el indicativo fijo `'CO +57'` se reemplazó por
  `AppPhoneField` alimentado por el maestro y la opción "Administrador" ya
  no aparece en el registro público. Pendiente: la pantalla "Cuenta en
  revisión" (hoy el propietario pendiente solo ve un mensaje en el login).
- `login_page.dart` tiene más de 1100 líneas. Al tocarlo, extraer los
  componentes reutilizables a `lib/widgets/` en lugar de seguir creciendo el
  archivo.
- Las pruebas del controller deben inyectar un servicio de autenticación
  falso, un `LocalPreferencesService` en memoria y repositorios falsos (de
  maestros y de acceso del administrador). Ninguna prueba debe depender de
  red real. Incluir casos con cadenas de inyección SQL y con cada regla de
  formato.

### Intención visual

- **Login**: logo y título "Machuco" arriba, selector de pestañas
  "Iniciar sesión / Registrarse", formulario dentro de un AppCard con
  correo, contraseña (con botón mostrar/ocultar), casilla "Recordar mi
  correo", enlace "¿Olvidaste tu contraseña?" y botón principal "Ingresar".
  Los botones secundarios "Continuar con Google" y "Continuar con GitHub"
  quedan ocultos o deshabilitados ("Próximamente") hasta que se implementen.
- **Aviso de modo desarrollo [Temporal]**: banner informativo (tono warning
  del design system) visible en la parte superior mientras se use el login
  quemado, con la lista desplegable de usuarios de prueba.
- **Registro**: una sola pantalla con scroll, sin stepper. Primero va el
  tipo de perfil (tarjetas seleccionables: **Cliente y Propietario**),
  porque define el resto del formulario. Luego: nombres y apellidos
  (sin campos de documento) → indicativo + celular
  (en una fila) → **bloque propio del rol** dentro de un AppCard con título
  (Cliente: fecha de nacimiento; Propietario: tipo de persona, NIT, si es
  jurídica razón social, y los planes de suscripción como tarjetas
  seleccionables con nombre, precio, periodicidad y características) → correo → contraseña → confirmación →
  enlace "Términos y condiciones" → "Crear cuenta". Los bloques que
  aparecen o desaparecen según el rol usan una transición corta con los
  tokens de duración del design system. Los errores de formato se muestran
  debajo de cada campo con el color de error del design system.
- **Términos y condiciones**: botón de texto (estilo enlace) que abre un
  AppBottomSheet con título, texto provisional y botón "Cerrar".
- **Cuenta en revisión** (Propietario): pantalla de estado con ícono,
  mensaje explicativo, el correo registrado y el botón "Cerrar sesión".
  Variante "Solicitud rechazada" con el motivo.
- **Administradores** (Administrador): lista en AppCards con nombre, correo
  y estado; botón principal "Crear administrador" que abre un formulario
  con los mismos componentes y validaciones del registro (sin contraseña).
- **Solicitudes de propietarios** (Administrador): lista en AppCards con
  nombre o razón social, tipo de persona, correo y fecha; contador de
  pendientes en el acceso desde el perfil; estado vacío y estado de error
  con "Reintentar". El detalle muestra todos los datos y los botones
  "Aprobar" (principal) y "Rechazar" (secundario/peligro); rechazar abre un
  AppBottomSheet con el campo de motivo obligatorio.
- **Selector de indicativo**: un campo compacto con bandera e indicativo
  (p. ej. "🇨🇴 +57"). Al tocarlo abre un AppBottomSheet con buscador y una
  lista de país, nombre e indicativo.
- **Estados de los selectores**: cargando (skeleton dentro del campo),
  error (mensaje corto y "Reintentar") y vacío (en la búsqueda).
- **Recuperación de contraseña**: AppBottomSheet con el campo de correo y el
  botón "Enviar instrucciones". Al confirmar muestra el mensaje neutro.

### Nota sobre la construcción de la interfaz (UI)

El selector de indicativo debe construirse como widget genérico en
`lib/widgets/` (p. ej. `AppPhoneField`) que reciba los datos por
parámetro, sin conocer Supabase ni el login. Así otras ramas (perfil de
cliente, registro de propietario, PQRS) pueden reutilizarlos. Usar siempre
los tokens del design system, sin colores, radios ni duraciones fijos
(el `height: 52` actual del indicativo debe pasar a un token o al propio
`AppTextField`).
