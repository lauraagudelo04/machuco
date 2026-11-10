# Handoff de autenticación para otras ramas

Rama de origen: `feature-juan_pablo`, a partir del commit `3bb5397`. Fecha:
2026-11-04. Aquí está lo que otras ramas deben enlazar o corregir. La rama
de autenticación no edita sus archivos.

## 1. `AppButton` se desborda con textos largos (rama del design system)

- **Archivo**: `lib/core/design_system/components/app_button.dart:37`.
- **Problema**: la etiqueta se pinta en
  `Row(mainAxisSize: MainAxisSize.min, children: [Icon…, Text(widget.label)])`
  sin `Flexible`. Con un texto largo ("Eliminar definitivamente"), una
  fuente grande o el escalado de texto al 200 %, el `Text` no se ajusta y
  Flutter muestra la franja de desbordamiento.
- **Propuesta**: envolver el `Text` en `Flexible` con `textAlign` centrado y
  `overflow: TextOverflow.ellipsis` o `softWrap: true`, y agregar una prueba
  de widget con `MediaQuery(textScaler: TextScaler.linear(2))` y un ancho de
  320 px.
- **Quién lo usa hoy**: `lib/widgets/auth/delete_account_sheet.dart`, el
  registro, el login y las vistas del administrador. Las pruebas de
  autenticación usan un viewport ancho para no chocar con el error.

## 2. Enlazar "Eliminar cuenta" (perfiles de cliente y propietario, menú del administrador)

Hoy solo aparece en la tarjeta de sesión activa del login y en "Cuenta en
revisión". Cada rol debería verlo en su perfil o menú.

```dart
import 'package:machuco/controllers/auth/login_controller.dart';
import 'package:machuco/views/login/logout_navigation.dart';
import 'package:machuco/widgets/auth/delete_account_sheet.dart';

Future<void> _onDeleteAccount(BuildContext context, LoginController controller) async {
  final deleted = await showDeleteAccountSheet(context, controller: controller);
  if (deleted && context.mounted) {
    goToLogin(context, notice: 'Tu cuenta fue eliminada');
  }
}
```

- Firma: `Future<bool> showDeleteAccountSheet(BuildContext context, {required LoginController controller})`
  (`lib/widgets/auth/delete_account_sheet.dart:11`). Devuelve `true` solo si
  la cuenta se eliminó.
- `goToLogin(context, {String? notice})` (`lib/views/login/logout_navigation.dart:20`)
  limpia la pila de navegación.
- Hay que usar **el mismo `LoginController`** de la sesión. Si la vista no
  lo tiene, pedirlo por parámetro; no crear uno nuevo con Firebase dentro de
  la vista.
- El acceso va al final del perfil, con el estilo de peligro del design
  system.
- **Cambio previsto** (Etapa 4 del [plan](plan-auth-social.md)): para
  cuentas solo de Google o GitHub, el panel pedirá confirmar con el
  proveedor en lugar de la contraseña. La firma no cambia.
- **Limitación**: no se comprueba si el usuario tiene reservas activas,
  moteles o si es el último administrador. Si una rama lo necesita, debe
  bloquear el acceso antes de abrir el panel.
- Por ahora la subcolección `users/{uid}/subscriptions` queda huérfana al
  eliminar la cuenta (rama de suscripciones).

## 3. Enlazar "Solicitudes de propietarios" (menú o panel del administrador)

```dart
import 'package:machuco/routes/routes.dart';

Navigator.of(context).pushNamed(AppRoutes.adminOwnerApprovals);
```

- `AppRoutes.adminOwnerApprovals` es `'/auth/admin/owner-approvals'`. La
  ruta ya está envuelta en `AdminRouteGuard`: si la sesión no es de un admin
  activo, muestra "Acceso restringido" y vuelve al login.
- Para mostrar el contador de pendientes en el acceso, crear un
  `AdminAccessController(repository: FirestoreAdminAccessRepository())`,
  llamar `loadPendingOwners()`, leer `pendingCount` y pasar el mismo
  controller como `arguments` para no volver a consultar.
- Otras rutas disponibles: `AppRoutes.adminOwnerApprovalDetail` (la abre la
  lista) y `AppRoutes.adminAdministrators` (gestión de administradores).
- **Requisito para que funcione:** que cada documento `users/{uid}` de
  administrador tenga `accountStatus: 'active'`. Las reglas y el índice de
  `users` ya están desplegados; quien despliegue `firestore.rules` desde otra
  rama debe partir de esta versión para no sobrescribirlos.

## 4. Lo que cambia para todas las ramas con Google y GitHub

Google y GitHub ya están implementados y habilitados en Firebase.

**Para usarlos no hay que registrar nada en Firebase.** Todo el equipo firma
con el mismo keystore de desarrollo, cuyo SHA-1 ya está registrado:

1. Lleva estos cambios a tu rama.
2. Pide a Juan Pablo `debug.keystore` y `key.properties`, que se comparten de
   forma privada, y cópialos en `android/`.
3. Verifica la firma con `cd android && ./gradlew :app:signingReport`.

Detalle en [android-setup.md](android-setup.md), sección 3. **Nunca subas esos
dos archivos al repositorio**: es público. Sin ellos la app compila, pero
Google y GitHub fallan.

También cambia lo siguiente:

- Una sesión con perfil incompleto no debe llegar a ninguna vista de rol.
  Mientras no exista el guard común (Etapa 5), las ramas no deben abrir sus
  rutas con `pushNamed` a partir de un `AuthSession` sin revisar su
  `accountStatus`.
- El correo de `AuthPreferences.loadCurrentUserEmail()` puede venir de
  Google o GitHub. Sigue sirviendo para mostrar y precargar, nunca para
  autorizar.
- `AuthSession.name` puede venir del `displayName` del proveedor hasta que
  el usuario complete su perfil.

## 5. Coordinación pendiente

| Tema | Con quién | Acción |
| --- | --- | --- |
| Versión 14 de SQLite (`auth_user_profile`) | Todas las ramas con `app_database.dart` | `develop` usa la 13 para limpiar ejemplos de room y autenticación la 14. Quien agregue una migración usa la 15 |
| Plugin `google-services` 4.4.4 → 4.5.0 y bloque FlutterFire | Quien administre la configuración de Firebase | Acordar la versión y no editar a mano el bloque `START/END: FlutterFire Configuration` |
| `applicationId` nuevo (`co.machuco.app` y `co.machuco.app.dev`) | Todo el equipo | Ya fijado (D2 del plan). Si ya tienes instalada la misma app firmada con otra llave, desinstálala antes de ejecutarla |
| Keystore de desarrollo compartido | Cada integrante | Copiar los dos archivos de la sección 4; no registrar huellas propias en Firebase |
