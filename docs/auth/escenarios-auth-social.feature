# Escenarios de ingreso y registro con Google y GitHub (Android).
# Rama feature-juan_pablo. Contrato y etapas en plan-auth-social.md.
# Etiquetas: @google @github @manual (requiere dispositivo y Firebase real)
#            @etapaN (etapa del plan que lo implementa) @decision-Dn (depende de una decisión)

Feature: Ingreso y registro con proveedores externos

  Background:
    Given el proyecto de Firebase "machuco" con los proveedores Google y GitHub habilitados
    And las reglas de Firestore y el índice de "users" desplegados

  # ---------- Registro e ingreso ----------

  @google @etapa3 @manual
  Scenario: Registro con Google de un usuario nuevo
    Given un visitante sin cuenta en Machuco
    When toca "Continuar con Google" y elige su cuenta de Google
    Then Firebase Auth crea el usuario con el proveedor "google.com"
    And el sistema obtiene SocialAuthIncompleteProfile con su correo verificado y su nombre
    And navega a "Completar perfil" con nombres y apellidos precargados y el correo en solo lectura

  @google @etapa3 @manual
  Scenario: Ingreso con Google de un usuario con perfil completo
    Given un cliente activo registrado con Google
    When toca "Continuar con Google"
    Then el sistema obtiene SocialAuthActive
    And guarda el perfil básico en SQLite y el correo en SharedPreferences
    And navega a la ruta del cliente

  @github @etapa3 @manual
  Scenario: Registro con GitHub de un usuario nuevo con correo público
    Given un visitante con una cuenta de GitHub cuyo correo es público y verificado
    When toca "Continuar con GitHub" y autoriza la OAuth App de Machuco
    Then Firebase Auth crea el usuario con el proveedor "github.com"
    And el sistema navega a "Completar perfil" con el correo de GitHub en solo lectura

  @github @etapa3 @manual
  Scenario: Ingreso con GitHub de un usuario con perfil completo
    Given un cliente activo registrado con GitHub
    When toca "Continuar con GitHub"
    Then el sistema obtiene SocialAuthActive y navega a la ruta del cliente

  # ---------- Cancelación, conexión y configuración ----------

  @google @github @etapa3
  Scenario Outline: El usuario cancela el flujo del proveedor
    Given un visitante en la pantalla de login
    When toca "<boton>" y cierra la ventana del proveedor sin terminar
    Then el sistema obtiene SocialAuthCancelled
    And permanece en el login sin mostrar error y con el formulario de correo intacto

    Examples:
      | boton                 |
      | Continuar con Google  |
      | Continuar con GitHub  |

  @google @github @etapa3
  Scenario: Sin conexión al iniciar el flujo social
    Given un dispositivo sin conexión
    When toca "Continuar con Google" o "Continuar con GitHub"
    Then el sistema obtiene SocialAuthError de tipo network
    And muestra "No hay conexión. Revisa tu internet e intenta nuevamente." con "Reintentar"

  @google @etapa3 @manual
  Scenario: SHA-1 no registrado o google-services.json desactualizado
    Given una compilación cuyo certificado no está registrado en Firebase
    When toca "Continuar con Google"
    Then el sistema obtiene SocialAuthError de tipo providerMisconfigured
    And muestra "El ingreso con Google no está configurado en esta versión de la app"
    And registra el detalle técnico solo en el log de depuración

  @github @etapa3 @manual
  Scenario: Proveedor deshabilitado en la consola
    Given el proveedor GitHub deshabilitado en Firebase Auth
    When toca "Continuar con GitHub"
    Then el sistema obtiene SocialAuthError de tipo providerMisconfigured sin crear usuario

  # ---------- Casos propios de GitHub ----------

  @github @etapa3 @manual
  Scenario: El usuario deniega el permiso en GitHub
    Given un visitante en la pantalla de autorización de GitHub
    When toca "Cancel" en lugar de "Authorize"
    Then el sistema obtiene SocialAuthCancelled y permanece en el login sin error

  @github @etapa3 @decision-D5 @manual
  Scenario: GitHub sin correo público ni verificado
    Given una cuenta de GitHub con el correo privado y sin correos verificados accesibles
    When completa el flujo de "Continuar con GitHub"
    Then el sistema obtiene SocialAuthError de tipo emailUnavailable
    And cierra la sesión de Firebase sin crear users/{uid}
    And explica que debe hacer público o verificar un correo en GitHub, o registrarse con correo y contraseña

  @github @etapa3 @manual
  Scenario: La OAuth App de GitHub fue recreada
    Given la OAuth App de GitHub recreada con un Client ID nuevo y Firebase actualizado con él
    When un usuario existente de GitHub toca "Continuar con GitHub" y vuelve a autorizar
    Then Firebase Auth lo identifica con el mismo uid del proveedor
    And el sistema obtiene SocialAuthActive sin duplicar la cuenta
    But si Firebase no se actualizó con el nuevo Client ID o Secret, obtiene SocialAuthError de tipo providerMisconfigured

  # ---------- Mismo correo y vinculación ----------

  @google @github @etapa4 @manual
  Scenario: Primero Google y luego GitHub con el mismo correo
    Given un usuario registrado con Google con el correo "ana@example.com"
    When intenta entrar con GitHub usando ese mismo correo
    Then el sistema obtiene SocialAuthError de tipo accountExistsWithDifferentCredential
    And indica que ya existe una cuenta con ese correo y que entre con Google para vincular GitHub
    When entra con Google y confirma "Vincular GitHub"
    Then GitHub queda vinculado al mismo uid y desde entonces puede entrar con cualquiera de los dos

  @google @github @etapa4 @manual
  Scenario: Primero GitHub y luego Google con el mismo correo verificado
    Given un usuario registrado con GitHub con el correo verificado "ana@example.com"
    When entra con Google usando ese mismo correo
    Then Firebase Auth usa la misma cuenta (Google es proveedor de confianza para ese correo)
    And el sistema no crea un segundo perfil y obtiene el resultado según el estado de la cuenta

  @google @etapa4 @decision-D7 @manual
  Scenario: Cuenta creada con contraseña que luego entra con Google
    Given un usuario registrado con correo y contraseña en "ana@gmail.com"
    When toca "Continuar con Google" con esa misma cuenta de Google
    Then el sistema no crea un perfil nuevo y conserva su rol y estado
    And si su correo estaba verificado, la contraseña sigue funcionando y Google queda vinculado
    But si su correo no estaba verificado, la app le avisa antes de continuar que la contraseña podría dejar de funcionar y le pide verificar el correo primero

  @etapa4
  Scenario: Desvincular un proveedor
    Given un usuario con contraseña y Google vinculados
    When desvincula Google desde su perfil
    Then conserva el acceso con contraseña
    But el sistema no permite desvincular el último método de acceso

  # ---------- Perfil incompleto ----------

  @etapa1 @etapa2
  Scenario: Perfil incompleto tras el primer ingreso social
    Given un usuario autenticado en Firebase sin documento users/{uid}
    When el sistema resuelve su sesión
    Then obtiene SocialAuthIncompleteProfile y nunca lo trata como cliente activo
    And ninguna ruta de cliente, propietario o administrador se abre hasta completar el perfil

  @etapa2
  Scenario: Completar perfil como Cliente
    Given un usuario en "Completar perfil"
    When elige Cliente y diligencia nombres, apellidos, indicativo, celular y una fecha de nacimiento de mayor de edad
    And acepta los términos y presiona "Guardar"
    Then se crea users/{uid} con rol client, accountStatus active y el correo del proveedor
    And navega a la ruta del cliente

  @etapa2
  Scenario: Completar perfil como Propietario
    Given un usuario en "Completar perfil"
    When elige Propietario, tipo de persona Jurídica, NIT "900123456-8", razón social y un plan
    And presiona "Guardar"
    Then se crea users/{uid} con rol owner y accountStatus pending_approval
    And navega a "Cuenta en revisión" y la solicitud aparece en "Solicitudes de propietarios"

  @etapa2
  Scenario: Completar perfil nunca ofrece Administrador
    Given un usuario en "Completar perfil"
    Then el selector de rol solo ofrece Cliente y Propietario
    And una petición manipulada con role admin es rechazada por las reglas

  @etapa2
  Scenario: Cierre de la app durante "Completar perfil" y reanudación
    Given un usuario en "Completar perfil" con datos escritos
    When cierra la app y la vuelve a abrir
    Then la restauración de la sesión obtiene SocialAuthIncompleteProfile
    And navega de nuevo a "Completar perfil" con los datos del proveedor precargados
    And lo que había escrito no se conserva

  @etapa2 @decision-D10
  Scenario: Cancelar "Completar perfil"
    Given un usuario en "Completar perfil"
    When presiona "Cancelar"
    Then el sistema borra el usuario de Firebase, cierra la sesión y vuelve al login
    And no queda ninguna cuenta a medias en Firebase
    And al entrar de nuevo con el mismo proveedor empieza un registro nuevo

  @etapa2 @decision-D10
  Scenario: Cancelar "Completar perfil" sin poder borrar el usuario
    Given un usuario en "Completar perfil" sin inicio de sesión reciente o sin conexión
    When presiona "Cancelar"
    Then el sistema cierra la sesión y vuelve al login sin abrir otra vez el proveedor
    And al entrar de nuevo con el mismo proveedor retoma "Completar perfil"

  @etapa2 @decision-D10
  Scenario: Cancelar nunca borra una cuenta real
    Given un usuario con perfil en "users/{uid}", con contraseña, o cuyo perfil no se pudo leer
    When abandona "Completar perfil"
    Then el sistema solo cierra la sesión y conserva el usuario de Firebase

  # ---------- Estados de cuenta ----------

  @etapa1
  Scenario: Cliente activo con proveedor social
    Given un cliente con perfil completo y accountStatus active
    When entra con Google o GitHub
    Then obtiene SocialAuthActive y navega a la ruta del cliente

  @etapa1
  Scenario: Propietario pendiente con proveedor social
    Given un propietario con accountStatus pending_approval
    When entra con Google o GitHub
    Then obtiene SocialAuthPending y navega a "Cuenta en revisión"

  @etapa1
  Scenario: Propietario rechazado con proveedor social
    Given un propietario con accountStatus rejected y un motivo registrado
    When entra con Google o GitHub
    Then obtiene SocialAuthRejected con el motivo, sin sesión
    And ve la variante "Solicitud rechazada"

  @etapa1
  Scenario Outline: Cuenta deshabilitada con proveedor social
    Given una cuenta <origen>
    When entra con Google o GitHub
    Then obtiene SocialAuthDisabled, sin sesión ni perfil en SQLite

    Examples:
      | origen                                       |
      | con accountStatus disabled en Firestore      |
      | deshabilitada en Firebase Auth (user-disabled) |

  @etapa1 @manual
  Scenario: Administrador existente entra con proveedor social
    Given un administrador con role admin y accountStatus active en users/{uid}
    When entra con un proveedor vinculado a su correo
    Then obtiene SocialAuthActive y navega a la ruta del administrador
    And puede aprobar y rechazar solicitudes

  @etapa1
  Scenario: Administrador sin accountStatus
    Given un documento users/{uid} con role admin y sin el campo accountStatus
    When entra con contraseña, Google o GitHub
    Then el sistema obtiene SocialAuthError de tipo invalidConfiguration
    And muestra "Tu cuenta de administrador no está activa; contacta a otro administrador"
    And no muestra vistas de administrador cuyas acciones las reglas rechazarían

  # ---------- Fallas de persistencia ----------

  @etapa2
  Scenario: Falla al guardar users/{uid} en Firestore
    Given un usuario en "Completar perfil" con el formulario válido
    When la escritura en Firestore falla por red o por permission-denied
    Then el sistema conserva los datos del formulario y muestra el error con "Reintentar"
    And no navega ni guarda nada en SQLite

  @etapa1
  Scenario: Falla al guardar el perfil en SQLite
    Given un ingreso social exitoso
    When falla la escritura de auth_user_profile en SQLite
    Then el ingreso continúa y navega a la ruta del rol
    And el perfil local se guarda en el siguiente arranque

  # ---------- Recuperación y eliminación ----------

  @etapa4 @manual
  Scenario: Recuperación de contraseña en una cuenta solo social
    Given un usuario que solo tiene Google vinculado
    When solicita "¿Olvidaste tu contraseña?" con su correo
    Then la app muestra el mismo mensaje neutro que para cualquier correo
    And si usa el enlace de Firebase, la contraseña nueva se agrega como método de acceso sin quitar Google

  @etapa4
  Scenario: Eliminación de cuenta con contraseña
    Given un usuario con el proveedor "password"
    When confirma "Eliminar cuenta" con su contraseña y el texto "ELIMINAR"
    Then se reautentica con la contraseña, se borra users/{uid}, luego el usuario de Auth, y se limpian SQLite y SharedPreferences

  @etapa4 @manual
  Scenario Outline: Eliminación de cuenta con proveedor social
    Given un usuario cuyo único proveedor es <proveedor>
    When abre "Eliminar cuenta"
    Then el panel no pide contraseña sino "Confirmar con <nombre>" y el texto "ELIMINAR"
    When confirma
    Then se reautentica con reauthenticateWithProvider y luego borra el perfil y el usuario
    But si cancela la reautenticación, no se borra nada

    Examples:
      | proveedor  | nombre |
      | google.com | Google |
      | github.com | GitHub |

  # ---------- Sesión y rutas ----------

  @etapa1 @manual
  Scenario: Sesión persistente con proveedor social
    Given un usuario que entró con Google o GitHub y no cerró sesión
    When abre la app
    Then restoreSession devuelve el mismo resultado que el ingreso según su estado
    And no muestra el login

  @etapa1
  Scenario: Cierre de sesión con proveedor social
    Given un usuario autenticado con Google
    When selecciona "Cerrar sesión"
    Then se cierra la sesión de Firebase (y la de google_sign_in si D4 es la opción a)
    And el próximo "Continuar con Google" vuelve a ofrecer el selector de cuenta
    And se borran el perfil de SQLite y el correo de sesión

  @etapa5
  Scenario Outline: Rutas protegidas según el resultado
    Given una sesión con resultado <resultado>
    When se intenta abrir la ruta <ruta> con pushNamed
    Then el guard redirige a <destino>

    Examples:
      | resultado                   | ruta                          | destino                  |
      | SocialAuthIncompleteProfile | clientMotels                  | Completar perfil         |
      | SocialAuthPending           | ownerMotels                   | Cuenta en revisión       |
      | SocialAuthActive (cliente)  | /auth/admin/owner-approvals   | ruta del cliente         |
      | sin sesión                  | ownerManagement               | login                    |

  # ---------- Entornos y compilación ----------

  @decision-D8 @manual
  Scenario: Compilación dev
    Given el flavor dev con su propia app de Firebase (sufijo .dev)
    When un integrante compila en debug con su keystore de debug registrado
    Then Google y GitHub funcionan contra la app dev

  @decision-D2 @manual
  Scenario: Compilación prod
    Given el flavor prod con el applicationId definitivo y la firma de release
    When se compila en release
    Then Google funciona con el SHA de release registrado
    And la firma no usa la llave de debug

  @manual
  Scenario: Instalación desde Google Play
    Given la app firmada por Play App Signing
    When un usuario instala desde Google Play y toca "Continuar con Google"
    Then el ingreso funciona porque el SHA de Play App Signing está registrado en Firebase
    But si no está registrado, obtiene SocialAuthError de tipo providerMisconfigured

  @manual
  Scenario: Compilación iOS
    Given un equipo macOS con Xcode
    When se ejecuta flutter build ios --no-codesign
    Then la app compila aunque los proveedores sociales de iOS no estén configurados
    And en iOS los botones sociales se muestran deshabilitados con "Próximamente" mientras falten GoogleService-Info.plist y el URL scheme
