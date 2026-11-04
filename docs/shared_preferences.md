# Librería: `shared_preferences`

> Estado de este documento: **adoptado en la rama `feature-juan_pablo`
> (módulo Bookings) y ratificado por el equipo como convención transversal de
> persistencia local no sensible para el resto de las 17 ramas.** Las
> decisiones de la sección 9 (2026-09-23, ver
> [`decisions_log.md`](decisions_log.md)) quedan cerradas y reflejadas en
> [`README.md#tecnologías`](../README.md#tecnologías). `shared_preferences` ya
> está en `pubspec.yaml` y la capa de acceso vive en `lib/service/storage/`.

## 1. Qué es

`shared_preferences` es el plugin oficial del equipo de Flutter
(`flutter.dev` / paquete publicado por `flutter.dev` en pub.dev) para
persistir **pares clave-valor simples** en el dispositivo, de forma asíncrona
y ligera. No es una base de datos: no soporta relaciones, consultas ni
colecciones complejas.

Es un paquete **federado** (federated plugin): `shared_preferences` expone la
API común en Dart puro, y delega en implementaciones específicas por
plataforma que ya vienen incluidas como dependencias transitivas al declarar
el paquete principal:

- `shared_preferences_android` → usa `SharedPreferences` nativo de Android.
- `shared_preferences_foundation` → usa `NSUserDefaults` en iOS/macOS.
- `shared_preferences_web` → usa `window.localStorage` en Flutter Web.
- `shared_preferences_linux` / `shared_preferences_windows` → usan un archivo
  JSON local en el directorio de soporte de la app.

Referencia oficial: <https://pub.dev/packages/shared_preferences>.

## 2. Para qué sirve

Sirve exclusivamente para datos pequeños, no sensibles y no relacionales que
la app necesita recordar entre sesiones sin backend, por ejemplo:

- Preferencias de interfaz (tema claro/oscuro elegido manualmente, idioma).
- Flags de "ya visto" (onboarding completado, tutorial de una pantalla).
- Última selección del usuario en un filtro u ordenamiento.
- Contadores o marcas de tiempo simples (última sincronización, último
  recordatorio mostrado).
- Un identificador o flag no sensible para restaurar el estado visual de una
  pantalla al reabrir la app.

**No sirve para:**

- Tokens de sesión, contraseñas o cualquier credencial → usar almacenamiento
  cifrado (`flutter_secure_storage` sobre Keychain/Keystore), nunca
  `shared_preferences` en texto plano.
- Colecciones grandes o datos estructurados con relaciones (listas de
  reservas, catálogos, historial completo) → corresponde a una base de datos
  local (`sqlite`/`drift`/`isar`/`hive`) o al backend, no a este plugin.
- Como sustituto de un repositorio/backend real: sigue siendo almacenamiento
  **local al dispositivo**, no se sincroniza entre dispositivos ni sobrevive
  a una desinstalación.

## 3. Cómo funciona internamente

1. La API de Dart llama, vía **platform channels**, a la implementación
   nativa correspondiente a la plataforma en la que corre la app.
2. Cada plataforma persiste los datos en su mecanismo propio (archivo XML en
   Android, plist en iOS/macOS, `localStorage` en Web, JSON en
   Windows/Linux), fuera del proceso Dart.
3. Todas las operaciones son **asíncronas** (`Future`) porque implican una
   llamada de plataforma, aunque en la práctica sean rápidas por ser lecturas
   locales.
4. Los tipos soportados son limitados a nivel de la API: `int`, `double`,
   `bool`, `String` y `List<String>`. Cualquier objeto propio del dominio
   (por ejemplo un filtro compuesto) debe serializarse manualmente (p. ej. a
   JSON con `jsonEncode`/`jsonDecode`) antes de guardarlo como `String`.

### API vigente (importante: hay dos generaciones conviviendo)

El paquete tuvo un rediseño de API a partir de la versión `2.3.0`:

- **API legada** (`SharedPreferences.getInstance()`): un singleton que carga
  *todas* las claves en memoria la primera vez que se usa. Sigue funcionando
  y es la que aparece en la mayoría de tutoriales, pero el propio paquete la
  marca como superada.
- **API nueva recomendada** (`SharedPreferencesAsync` y
  `SharedPreferencesWithCache`): no usa un singleton global, lee/escribe
  directo a la plataforma (`SharedPreferencesAsync`) o con una caché
  explícita y acotada por prefijo/allowlist de claves
  (`SharedPreferencesWithCache`), evitando el problema de cargar todas las
  claves de la app en memoria innecesariamente.

**Decisión para MACHUCO (2026-09-23, reemplaza la recomendación inicial):**
se usa **la API clásica `SharedPreferences.getInstance()`**. No se usan
`SharedPreferencesAsync` ni `SharedPreferencesWithCache` en ninguna parte del
proyecto. La API clásica es la que el equipo conoce y la que documentan los
materiales del curso; el costo de cargar todas las claves en memoria es
irrelevante para el volumen de preferencias de la app.

## 4. Cómo aportaría valor a este proyecto

MACHUCO hoy no tiene ninguna persistencia local real: `docs/architecture.md`
documenta que todo el estado vive en memoria (`static` en controladores) y se
pierde al cerrar la app. `shared_preferences` no reemplaza esa necesidad de
persistencia de dominio (reservas, moteles, etc. — eso corresponde a la
decisión de backend/base de datos, todavía pendiente), pero cubre un problema
distinto y más pequeño que ya existe en la app: recordar preferencias de UI
entre sesiones. Ejemplos concretos ligados al contexto de esta rama
(`contexts/people/feature-juan_pablo.feature.md`, módulo de Bookings):

- Recordar el último filtro/orden elegido en "Mis reservas" (Cliente) o en
  "Reservas de mis hoteles" (Propietario) para no perderlo al reabrir la
  pantalla.
- Recordar el motel seleccionado por un propietario con más de un motel, para
  no obligarlo a re-seleccionar cada vez que entra a Reservas.
- Marcar como "visto" un mensaje o aviso puntual (por ejemplo, un aviso sobre
  el estado "pendiente" de la factura al pagar en efectivo).

Ninguno de estos casos es dominio de negocio (no reemplaza `Reservation` ni
el futuro backend); son mejoras de continuidad de experiencia de usuario que
no requieren red ni backend.

## 5. Forma de uso dentro de MACHUCO (API clásica, envuelta)

Nadie usa el plugin directamente. Cada módulo crea su propia instancia de
`SharedPreferencesLocalService` con un **namespace de funcionalidad** y
depende del tipo `LocalPreferencesService`:

```dart
import 'package:machuco/service/storage/local_preferences_service.dart';
import 'package:machuco/service/storage/shared_preferences_local_service.dart';

class ClientBookingController extends ChangeNotifier {
  ClientBookingController({LocalPreferencesService? preferences})
    : _preferences =
          preferences ?? SharedPreferencesLocalService(namespace: 'bookings');

  final LocalPreferencesService _preferences;

  // Claves del módulo, definidas en el propio módulo (no en un archivo
  // compartido): se guardan como 'bookings.lastFilterMotelId'.
  static const _lastFilterMotelIdKey = 'lastFilterMotelId';

  Future<void> loadPreferences() async {
    final lastMotelId = await _preferences.getString(_lastFilterMotelIdKey);
    // ... aplicar y notifyListeners()
  }

  Future<void> selectMotel(String motelId) =>
      _preferences.setString(_lastFilterMotelIdKey, motelId);
}
```

Métodos disponibles: `getString`/`setString`, `getBool`/`setBool`,
`getInt`/`setInt`, `getDouble`/`setDouble`,
`getStringList`/`setStringList`, `containsKey`, `remove` y `clear` (este
último borra **solo** las claves de su namespace).

Puntos clave:

- Internamente se usa `SharedPreferences.getInstance()` (singleton de la API
  clásica). Se obtiene de forma perezosa en la primera lectura/escritura, así
  que el servicio puede instanciarse en un constructor o en `initState` sin
  tocar `main.dart`.
- La interfaz expone todo como `Future` para que el contrato no dependa de
  que el singleton ya esté cargado.
- No hay valor por defecto automático: si la clave no existe, el getter
  devuelve `null`; el `??` para el valor por defecto lo decide quien llama.
- Leer una clave con un tipo distinto al que se guardó lanza error (la API
  clásica hace un *cast*): cada clave debe tener un único tipo.

## 6. Cómo implementarla — paso a paso de configuración

1. **Acordar con el equipo** que se adopta este paquete para persistencia
   local de preferencias (ver advertencia de la sección 8 — esto no lo
   decide una sola rama).
2. Dependencia ya agregada en `pubspec.yaml` (no hace falta repetirlo en
   ninguna rama):
   ```yaml
   dependencies:
     shared_preferences: ^2.5.5
   ```
3. Ejecutar `flutter pub get`.
4. No se requiere configuración nativa adicional (permisos, `Info.plist`,
   `AndroidManifest.xml`) para el uso básico en Android/iOS: el plugin
   gestiona su propio almacenamiento sin acceso a almacenamiento externo del
   dispositivo.
5. **No llamar el plugin directamente desde una vista ni desde un
   controlador sin envolverlo.** Según las reglas no negociables del
   proyecto (`CLAUDE.md`), el acceso a datos debe quedar separado de la UI y
   de la lógica de presentación. Se propone:
   - La interfaz `lib/service/storage/local_preferences_service.dart`
     (`LocalPreferencesService`) es **genérica** (clave-valor con
     namespace): no contiene métodos de ninguna funcionalidad concreta, para
     que ninguna rama tenga que modificarla al agregar una preferencia y para
     que siga sirviendo cuando las personas cambien de funcionalidad en la
     segunda etapa.
   - La implementación concreta,
     `lib/service/storage/shared_preferences_local_service.dart`
     (`SharedPreferencesLocalService`), es la única clase del proyecto que
     importa `package:shared_preferences/shared_preferences.dart`.
   - Los controladores (`ChangeNotifier`) dependen de la interfaz
     `LocalPreferencesService`, no de la implementación concreta, siguiendo
     el mismo patrón que ya usa `RegisteredUserDirectory` en el módulo de
     auth (ver `docs/modules/auth.md`).
6. Inyectar la implementación concreta donde hoy se instancia el controlador
   (por ejemplo en `initState` de la vista), igual que se hace con el resto
   de dependencias mockeadas del proyecto, hasta que exista un mecanismo de
   inyección de dependencias acordado por el equipo.

## 7. Instrucciones de uso dentro de MACHUCO

- **Convención de nombres de clave:** el namespace y la clave van en
  `lowerCamelCase` y sin puntos (el servicio lo valida y lanza
  `ArgumentError` si no se cumple); el servicio los une como
  `<namespace>.<clave>`, por ejemplo `bookings.lastFilterMotelId`,
  `auth.onboardingSeen`. Evita colisiones entre las 17 ramas que comparten el
  mismo espacio de claves de `shared_preferences`.
- **El namespace es la funcionalidad, nunca la persona ni la rama.** Usar el
  nombre del módulo (`bookings`, `pqrs`, `payments`, `reviews`...), igual que
  las carpetas de `lib/`. Nunca `juanPablo` o `featureX`: las ramas son por
  persona y en la segunda etapa cada persona cambia de funcionalidad, así que
  las claves deben sobrevivir a ese cambio de dueño.
- **Las claves se definen dentro del módulo** que las usa (constantes
  privadas del controlador o servicio), no en un archivo central compartido,
  para no generar conflictos de merge entre ramas.
- **Nunca guardar objetos de dominio completos como JSON "por comodidad"**
  sin evaluar antes si ese dato en realidad pertenece a una base de datos
  local o al backend. `shared_preferences` es para preferencias, no para
  reemplazar la ausencia de una capa `data`/`repository`.
- **No es reactivo por sí mismo:** a diferencia de `ChangeNotifier`, escribir
  con `shared_preferences` no notifica a la UI. Si una preferencia debe
  reflejarse en pantalla, el propio controlador debe leerla al inicializarse
  y llamar `notifyListeners()` después de actualizarla, como ya hace con el
  resto de su estado.
- **Manejar siempre el caso `null`** al leer una clave que puede no existir
  todavía (primera vez que corre la app, o clave nunca escrita).

## 8. Advertencias y elementos a tener en cuenta

- **Decisión de almacenamiento ya acordada por el equipo (2026-09-23).**
  `README.md#tecnologías` y `CLAUDE.md` marcan "el almacenamiento" (junto con
  backend, base de datos, pasarela de pagos y gestor de estado) como una
  decisión que no debe fijarse sin acuerdo del equipo completo. Para
  `shared_preferences` ese acuerdo ya se dio: queda registrado en
  [`decisions_log.md`](decisions_log.md) y reflejado en
  [`README.md#tecnologías`](../README.md#tecnologías). Esto cubre únicamente
  persistencia local no sensible de preferencias de UI; backend, base de
  datos y almacenamiento de imágenes siguen pendientes de decisión.
- **No es para datos sensibles.** En Android/iOS los datos no están cifrados
  por defecto de forma robusta a nivel de este plugin; para tokens, sesiones
  o cualquier credencial la alternativa correcta es
  `flutter_secure_storage`, no `shared_preferences`.
- **No es transaccional.** No hay forma de agrupar varias escrituras como una
  sola operación atómica; si dos escrituras dependen entre sí y una falla, no
  hay rollback automático.
- **Límites en Web:** usa `localStorage`, con un límite típico de ~5-10 MB
  por origen impuesto por el navegador, y puede no persistir (o persistir
  solo durante la sesión) en modo incógnito/privado según el navegador.
- **No sincroniza entre dispositivos** ni sobrevive a una desinstalación de
  la app (ni, en iOS, a una restauración de backup sin el flag adecuado en
  `NSUserDefaults`, que este plugin no configura por defecto).
- **Testing:** en pruebas de widgets/controladores que usen
  `SharedPreferencesLocalService` real, llamar
  `SharedPreferences.setMockInitialValues({})` en `setUp` (con los valores
  iniciales que se necesiten, usando la clave completa
  `'<namespace>.<clave>'`). Alternativamente, inyectar un fake de la
  interfaz `LocalPreferencesService` en el controlador — otra razón para no
  acoplar controladores al plugin. Ver
  `test/service/storage/shared_preferences_local_service_test.dart`.
- **Costo de no envolverlo:** si `SharedPreferences`
  se importa directamente en una vista o en un controlador sin pasar por una
  interfaz propia, cualquier cambio futuro de estrategia de almacenamiento
  local (por ejemplo migrar a `Hive` o a una base de datos local) obliga a
  tocar cada punto de uso en vez de una sola implementación.

## 9. Decisiones tomadas (2026-09-23, ratificadas por el equipo completo)

| Pregunta | Decisión | Alcance |
|---|---|---|
| ¿Se adopta `shared_preferences` para preferencias locales no sensibles? | **Sí.** | Cerrado para todo el proyecto. |
| ¿Qué API se usa? | **API clásica `SharedPreferences.getInstance()`**. No se usan `SharedPreferencesAsync` ni `SharedPreferencesWithCache`. (Reemplaza la elección inicial de `SharedPreferencesAsync`.) | Convención acordada para todo el proyecto. |
| ¿Dónde vive la capa de acceso? | **`lib/service/storage/`**, con la interfaz genérica `LocalPreferencesService` y la implementación `SharedPreferencesLocalService`, siguiendo el patrón de `service/auth/`. | Convención acordada para todo el proyecto. |
| ¿Cómo se separan las preferencias de cada módulo? | Por **namespace de funcionalidad** (`SharedPreferencesLocalService(namespace: 'bookings')`), nunca por persona o rama. | Convención acordada para todo el proyecto. |
| ¿Alcance inicial? | Nació en la rama `feature-juan_pablo` (módulo Bookings) y quedó ratificada por el equipo como convención transversal para las 17 ramas, en vez de que cada una resuelva "almacenamiento" por su cuenta. | Cerrado. |

**Importante:** esta decisión ya cuenta con el acuerdo formal del equipo
completo que exige `CLAUDE.md` para fijar "almacenamiento" a nivel de todo el
proyecto, por eso se refleja como hecho cerrado en
[`README.md#tecnologías`](../README.md#tecnologías) además de en
[`decisions_log.md`](decisions_log.md).

## Referencias

- Paquete oficial: <https://pub.dev/packages/shared_preferences>
- Reglas del proyecto sobre dependencias y almacenamiento: `CLAUDE.md`,
  sección "Reglas no negociables".
- Estado de decisiones pendientes: [`README.md`](../README.md#tecnologías) y
  [`decisions_log.md`](decisions_log.md).
- Patrón de interfaz + implementación ya usado en el proyecto para una
  dependencia externa: [`modules/auth.md`](modules/auth.md)
  (`RegisteredUserDirectory`).
