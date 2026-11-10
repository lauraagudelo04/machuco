# Pruebas de reglas de Firestore de MACHUCO

Suite compartida de autenticación, reservas y pagos; origen en la rama
`feature-juan_pablo` (decisión D9 de `docs/auth/plan-auth-social.md`). Ninguna prueba toca el proyecto real de
Firebase: el emulador usa el proyecto ficticio `demo-machuco`.

## 1. Reglas de Firestore y contrato del repositorio de aprobaciones (Node)

Requisitos: Node 20 o superior, `firebase-tools` (`npm i -g firebase-tools`)
y un JDK 21. Sirve el de Android Studio; el Java 1.8 de Oracle no funciona.

```bash
cd test_rules
npm ci
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"   # Git Bash en Windows
npm run test:emulator
```

En PowerShell: `$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"`.

`npm run test:emulator` levanta el emulador de Firestore (`127.0.0.1:8080`,
según `firebase.json`), corre los archivos del script `npm test` en serie y lo apaga. Si ya
tienes el emulador abierto con `firebase emulators:start --only firestore
--project demo-machuco`, puedes correr solo `npm test`.

Los `PERMISSION_DENIED` que aparecen en la salida son las denegaciones que
las pruebas esperan. El resultado está en el resumen final (`ℹ fail 0`).

| Archivo | Qué prueba | ID |
| --- | --- | --- |
| `users.rules.test.mjs` | Registro con campos válidos e inválidos, lectura y escritura del propio perfil, decisiones del admin, eliminación | sin ID, `[SOC-14]` |
| `account_status.rules.test.mjs` | Bloqueo de propietarios y clientes pendientes, rechazados o deshabilitados (colección `payments`), admin activo, sin `accountStatus` o deshabilitado | `[EST-01]`–`[EST-08]` |
| `admin_access.contract.test.mjs` | Réplica de la consulta y de la transacción de `FirestoreAdminAccessRepository`: listar, aprobar, rechazar, doble decisión y concurrencia | `[ADM-01]`–`[ADM-11]` |
| `reservations.rules.test.mjs` | Creación por cliente, participantes, consultas y prohibición de acreditar el sandbox de tarjeta | `[RES-01]`–`[RES-08]` |
| `payments.rules.test.mjs` | Vínculo real con reserva, selección pendiente y recepción atómicas, reintento, permisos, datos alterados y vencimiento | sin ID |
| `shared_collections.rules.test.mjs` | Regresión de los bloques ya publicados de additionalServices y el espejo motels; evita borrarlos por desplegar desde una rama desactualizada | sin ID |

**Por qué el repositorio se prueba con una réplica en Node.** `flutter test`
no carga el plugin nativo de `cloud_firestore`. Para ejecutar el código Dart
real contra el emulador hace falta una prueba de integración en un dispositivo
Android o en Windows con Visual Studio, y ninguno de los dos está en el
entorno actual. Si cambia la consulta o las escrituras de
`lib/database/repository/auth/admin_access_repository.dart`, actualiza las
funciones `listPendingOwners`, `approveOwner` y `rejectOwner` de
`admin_access.contract.test.mjs`.

**Limitación:** el emulador no exige índices compuestos. Que el índice de
`users` (`role`, `accountStatus`, `createdAt`) exista en el proyecto real se
verifica en la consola de Firebase.

Las pruebas marcadas **HALLAZGO** describen el comportamiento actual de las
reglas que conviene revisar; no son errores de la prueba.

**Política de eliminación confirmada por el usuario:** el administrador activo
puede eliminar perfiles de clientes/propietarios, nunca administradores.
La prueba anterior que negaba todo borrado ajeno contradecía la regla existente
y se corrigió tras confirmar explícitamente la política. Se prueban también
usuarios sin autoridad, administradores deshabilitados y contraseña temporal
pendiente. Las reglas de eliminación no se ampliaron.

## 2. Pruebas de Flutter (Dart)

```bash
flutter test                                   # todo
flutter test test/database/auth_migration_test.dart          # migraciones SQLite [MIG-xx]
flutter test test/repositories/auth                          # caché SQLite, catálogo, 13 -> 14
flutter test test/service/auth                               # servicios [SOC-xx]
flutter test test/views/auth                                 # pantallas [SOC-UI-xx]
```

SQLite corre con `sqflite_common_ffi` sobre archivos temporales; no necesita
emulador ni dispositivo.
