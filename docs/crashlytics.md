# Crashlytics (reportes de errores)

Firebase Crashlytics registra los errores que cierran la app (o que la app
decide reportar) y los muestra en la consola de Firebase, con la línea de
código, la versión y el dispositivo.

## Cómo está conectado

- Paquete: `firebase_crashlytics` en `pubspec.yaml`.
- Android: el plugin de Gradle `com.google.firebase.crashlytics` está en
  `android/settings.gradle.kts` (versión) y `android/app/build.gradle.kts`
  (aplicación).
- Código: `lib/service/crashlytics/crash_reporting_service.dart`.
  `CrashReporting.install(...)` se llama en `lib/main.dart` justo después de
  `Firebase.initializeApp` y conecta dos captadores:
  - `FlutterError.onError`: errores del framework (construcción de widgets,
    layout, gestos).
  - `PlatformDispatcher.instance.onError`: errores asíncronos que nadie
    capturó.
- Ninguna vista llama a Firebase. Quien quiera reportar un error que ya
  manejó usa `CrashReporting.reporter.recordError(error, stack)` (no fatal).
- Los reportes salen del teléfono con el mensaje del error y la traza:
  **nunca** pongas datos personales (nombres, correos, teléfonos) en el
  mensaje de una excepción.
- En modo debug los errores de Flutter se siguen mostrando en la consola.
- No se usa `firebase_analytics` para esto: Analytics es de otro equipo.

## Dónde ver los reportes

Consola de Firebase → proyecto `machuco` → Crashlytics. Hay una app por
sabor: `Machuco Dev` (`co.machuco.app.dev`) y `Machuco` (`co.machuco.app`).
Elige la app correcta en el selector; si no, la lista sale vacía.

## Cómo probarlo

1. Corre la app en un emulador o teléfono Android (Crashlytics no funciona en
   web ni en escritorio): `flutter run --flavor dev`.
2. Provoca un error de prueba, por ejemplo con un botón temporal que llame a
   `FirebaseCrashlytics.instance.crash()`. No lo subas al repositorio.
3. La app se cierra. Ábrela de nuevo: el reporte se envía en el siguiente
   arranque.
4. Revisa la consola; puede tardar unos minutos.

## Pendiente

- iOS: el plugin se instala con Swift Package Manager. Falta subir los
  símbolos (dSYM) y probar en un dispositivo iOS; sin ellos, los reportes de
  iOS salen sin símbolos (ilegibles).
