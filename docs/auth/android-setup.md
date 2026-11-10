# Entorno Android de MACHUCO (flavors, firma compartida y Firebase)

Corresponde al **Plan de autenticación social v1.0, aprobado el
2026-11-04** (ver [plan-auth-social.md](plan-auth-social.md), etapa 7). Esta
guía no contiene secretos: las contraseñas y el keystore se entregan por el
canal seguro del equipo.

## 1. Resumen

| Entorno | Flavor | `applicationId` | Nombre visible | App de Firebase (proyecto `machuco`) |
| --- | --- | --- | --- | --- |
| Desarrollo | `dev` | `co.machuco.app.dev` | Machuco Dev | `1:201797273193:android:222f631458ed0b780884f8` |
| Producción | `prod` | `co.machuco.app` | machuco | `1:201797273193:android:fb96e013e19b418c0884f8` |
| Antigua (solo ramas sin flavors) | — | `com.example.machuco` | machuco | `1:201797273193:android:478caeb42535587b0884f8` |

- Los dos flavors usan **el mismo proyecto de Firebase** (`machuco`), cada
  uno con su propia app Android. Dev y prod se instalan lado a lado sin
  sobrescribirse.
- El `namespace` de Gradle sigue siendo `com.example.machuco`, porque es el
  paquete del código Kotlin (`MainActivity`). No afecta la instalación ni
  Firebase.
- En Dart, `lib/firebase_options.dart` elige la app según el flavor
  (`appFlavor == 'dev'` → `androidDev`; si no, `android` = prod).
  **No ejecutes `flutterfire configure`** sin volver a agregar `androidDev`:
  lo sobrescribiría.

## 2. Java (JDK 17 o superior)

El build usa JDK 17+ (Gradle 9.1, AGP 9.0.1). **No pongas
`org.gradle.java.home` en `android/gradle.properties`**: esa ruta es propia
de cada equipo y rompe el build en los demás. Elige una opción:

1. Opción recomendada: dejar que Flutter use el JDK de Android Studio. Comprueba con
   `flutter doctor -v` que aparece "Java binary at: …Android Studio\jbr…". Si
   no aparece, ejecuta `flutter config --jdk-dir "<ruta a tu JDK 17+>"`.
2. Para usar `gradlew` directamente, define `JAVA_HOME` en tu sesión o en tu
   perfil (Windows: Variables de entorno; Git Bash:
   `export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"`).
3. Si necesitas fijarlo para Gradle en tu equipo, usa tu archivo personal
   `%USERPROFILE%\.gradle\gradle.properties` con `org.gradle.java.home=…`,
   nunca el del repositorio.

El `java` de Oracle 1.8 que algunos equipos tienen en el `PATH` no sirve ni
para Gradle ni para el emulador de Firestore.

## 3. Keystore de desarrollo compartido (un solo SHA-1)

Todo el equipo firma `dev` y `prod` en debug con **el mismo certificado**.
Por eso Firebase necesita un único SHA-1 para Google y GitHub (decisión D3).

| Dato | Valor |
| --- | --- |
| Archivo | `android/debug.keystore` (ignorado por `**/*.keystore`) |
| Alias | se entrega por el canal seguro |
| SHA-1 | `8F:EE:77:0B:B3:26:19:EF:C3:7A:A1:99:C6:98:58:92:79:D2:8A:FE` |
| SHA-256 | `7E:BB:F6:4F:B3:59:C0:60:6D:49:C8:A5:FA:16:23:27:E2:C5:D6:2F:96:A7:F9:44:F7:4F:2B:A0:14:59:F3:90` |
| Registrado en Firebase | `co.machuco.app` y `co.machuco.app.dev` (SHA-1 y SHA-256, 2026-11-05) |

Pasos para cada integrante:

1. Recibe el keystore y sus datos de acceso por el canal seguro acordado
   (por ejemplo, el gestor de contraseñas del equipo). **Nunca** por el
   repositorio, el chat del curso ni el correo sin cifrar.
2. Copia el archivo como `android/debug.keystore`.
3. Copia `android/key.properties.example` como `android/key.properties` y
   completa `storeFile=debug.keystore`, `storePassword`, `keyAlias` y
   `keyPassword`. Las rutas son relativas a `android/`.
4. Verifica la huella:
   `cd android && ./gradlew :app:signingReport` (con `JAVA_HOME` definido).
   Las variantes `devDebug` y `prodDebug` deben mostrar `Config: sharedDev`
   y el SHA-1 de la tabla.

Sin `android/key.properties`, Gradle avisa ("MACHUCO: falta
android/key.properties…") y firma con el debug local de tu equipo. La app
compila, pero Google y GitHub fallarán porque ese SHA-1 no está registrado.

**Riesgo aceptado**: este keystore reutiliza la llave de debug existente, con
los datos de acceso por defecto de Android. Solo sirve para desarrollo: no
publiques nada firmado con él.

## 4. Firma de producción

`prod` en release se firma con el keystore de release si `key.properties`
tiene `releaseStoreFile`, `releaseStorePassword`, `releaseKeyAlias` y
`releaseKeyPassword`. Si faltan, se firma con el keystore de desarrollo
(como antes), lo que sirve para probar pero **no para Google Play**. El
keystore de release y su SHA-1 aún no existen. Ver "Pasos manuales" en el
plan.

## 5. `google-services.json`

- Hay **un solo archivo compartido**: `android/app/google-services.json`
  (versionado). Contiene los clientes de `co.machuco.app`,
  `co.machuco.app.dev` y `com.example.machuco`. El plugin
  `com.google.gms.google-services` 4.4.4 elige el cliente según el
  `applicationId` de cada variante.
- No contiene secretos de servidor; la clave de API es pública y se protege
  con las reglas de Firestore.
- Cuando se registren nuevos SHA-1, quien los registre vuelve a descargar el
  archivo (`firebase apps:sdkconfig ANDROID <appId> --project machuco -o
  android/app/google-services.json`) y lo sube en un commit propio.

## 6. Comandos

| Acción | Comando |
| --- | --- |
| Ejecutar desarrollo | `flutter run` (o `flutter run --flavor dev`) |
| Ejecutar producción (debug) | `flutter run --flavor prod` |
| APK de desarrollo | `flutter build apk --debug` (o con `--flavor dev`) |
| APK de producción | `flutter build apk --flavor prod --release` |
| App Bundle para Google Play | `flutter build appbundle --flavor prod --release` (requiere el keystore de release) |
| Ver firmas y SHA por variante | `cd android && ./gradlew :app:signingReport` |

**Flavor por defecto:** `pubspec.yaml` declara `flutter: default-flavor: dev`
(Flutter 3.22 o superior). Por eso `flutter run` y `flutter build apk` sin
`--flavor` compilan **dev**, también desde VS Code y Android Studio sin
configuración extra. Producción siempre se pide explícitamente con
`--flavor prod`.

Sin `default-flavor`, `flutter run` sin `--flavor` compila todas las variantes
y falla con "Gradle build failed to produce an .apk file": no lo quites sin
cambiar también las configuraciones de ejecución del equipo.

Los APK quedan en `build/app/outputs/flutter-apk/app-<flavor>-<tipo>.apk`.

## 7. Pruebas de reglas de Firestore (emulador + Node)

Requisitos: Node 20 o superior, `firebase-tools` y JDK 21 (sirve el de
Android Studio).

```bash
cd test_rules
npm ci                     # instala @firebase/rules-unit-testing 6.0.0 y firebase 13.0.0
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"   # o el JDK 21 de tu equipo
npm run test:emulator      # levanta el emulador de Firestore y corre las pruebas
```

- Usan el proyecto ficticio `demo-machuco`: nunca tocan el proyecto real.
- `firebase.json` fija el emulador en `127.0.0.1:8080`, sin interfaz web.
- Los mensajes `PERMISSION_DENIED` en la salida son las denegaciones que
  las pruebas esperan. Lo que importa es el resumen final (`ℹ fail 0`).
- Antes de desplegar `firestore.rules`, estas pruebas deben pasar.
- Detalle de cada archivo de prueba, los ID y las pruebas de Flutter: [`test_rules/README.md`](../../test_rules/README.md).

## 8. Desplegar reglas e índices

```bash
firebase deploy --only firestore:rules,firestore:indexes --project machuco
```

Después, revisa en la consola (Firestore → Índices) que el índice de
`users` (`role`, `accountStatus`, `createdAt`) esté en estado "Habilitado".
