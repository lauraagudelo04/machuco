# Contexto - PQRS (rama: feature_josemanuelpavas)

> Documento de análisis y contexto. **No contiene implementación.** Compara la
> especificación recibida con lo que ya existe en `lib/` y define el alcance
> mínimo para esta rama. Es un proyecto universitario: se prefiere lo simple y
> cada decisión lleva su justificación.

## Rol de usuario que atiende esta funcionalidad

Cliente (radica, comenta y cierra) y Propietario (atiende, resuelve, rechaza,
y cierra por vencimiento). El responsable de esta rama es dueño de todo el
módulo PQRS, incluido `lib/models/pqrs/` y lo que consume la vista del
administrador. El Administrador del sistema tiene una vista de supervisión de
solo lectura (`system_admin_view/`) que queda fuera de esta especificación; solo
hay que verificar que siga compilando.

## Estado actual del código vs. lo requerido

El módulo PQRS existe completo en memoria (lo escribió originalmente la rama
`feature_daniel`; ver `contexts/people/feature_daniel.feature.md`, sección
"Alcance anterior: PQRS"). Falta **persistencia en Firestore, sesión real,
fotos reales y pruebas**.

| Requisito de la spec | Estado en el código | Dónde |
|---|---|---|
| Estados `pending`, `inProgress`, `resolved`, `closed`, `rejected` | Hecho (enum, `isFinal`) | `lib/models/pqrs/pqrs.dart` |
| Tipo de solicitud (petición, queja, reclamo, sugerencia) | Hecho (`PqrsType`) | `pqrs.dart` |
| Cliente radica (motel, tipo, asunto, descripción, fotos) | Hecho en memoria; motel y cliente fijos por constantes temporales | `client_view/pqrs_page.dart`, `PqrsController.createRequest` |
| Mis solicitudes | Hecho, filtrado por `pqrsCurrentClientId` (constante, no sesión) | `client_view/pqrs_page.dart` |
| Detalle + trazabilidad (timeline) | Hecho | `PqrsTimeline`, `*_detail_page.dart` |
| Cliente comenta sin cambiar estado | Hecho, **sin restringir por estado salvo final** y sin reabrir desde `resolved` | `addUpdate` |
| Cliente confirma y cierra desde `resolved` | Hecho (`closeByClient`) | `pqrs_controller.dart` |
| Cierre por vencimiento (propietario) | **No existe** | (por implementar) |
| Propietario: primer comentario pasa `pending` a `inProgress` | Hecho | `addUpdate` |
| Propietario resuelve / rechaza con motivo | Hecho (`markResolved`, `reject`); el motivo se guarda como mensaje de la trazabilidad, no como campo | `pqrs_controller.dart` |
| Estado final no admite cambios | Hecho (`_mutable` lanza `StateError`) | `pqrs_controller.dart` |
| Filtro del propietario por estado | Hecho (`ChoiceChip`) | `owner_view/pqrs_page.dart` |
| Estado vacío | Hecho en las tres listas | vistas |
| Mi desempeño (totales, tasas, conteos) | Hecho (`PqrsStats`, `PqrsStatsPanel`); mide "cerradas" como `closed` / total (`closureRate`) | `pqrs.dart` |
| Propietario solo ve PQRS de sus moteles | **Parcial/falso**: filtra por una constante `pqrsCurrentMotelId` (un solo motel) | `owner_view/pqrs_page.dart` |
| Persistencia en Firebase | **No existe**: `PqrsStore` es memoria con datos semilla | `pqrs_store.dart` |
| Reglas de Firestore para PQRS | **No existen**: `firestore.rules` no tiene `pqrs`; hoy `/{document=**}` las deniega | `firestore.rules` |
| Constante de colección | **No existe** en `FirestoreCollections` | `lib/service/firebase/firestore_collections.dart` |
| Fotos reales | **Decididas, pendientes de implementar** (bytes en Firestore, `image_picker`; ver D1). Hoy los adjuntos son simulados con `seed` | `PqrsAttachment.simulated` |
| Pruebas | **No hay** archivos de prueba de PQRS | `test/` |
| Autor real desde sesión | **No**: `pqrsCurrentClientId = '1'` | `pqrs_store.dart` |

Deuda de arquitectura presente (se reporta; se corrige al implementar):

- Las vistas usan `PqrsController.instance` (singleton) y `PqrsStore.instance`.
  Nada llega a un repositorio; hay que introducir uno (ver mapa de archivos).
- `lib/views/pqrs/pqrs_page.dart` contiene un selector de perfil de prueba
  (`PqrsProfilePicker`): es un andamio que se quita cuando haya sesión (D7).
- `client_view/pqrs_page.dart` llama a `MotelController` directamente desde la
  vista (línea ~81) para resolver el motel.

## Alcance

Incluye:

1. Persistir PQRS y su trazabilidad en Cloud Firestore (base principal), con
   caché y cola de envío local en Floor/SQLite para trabajar sin conexión.
2. **Fotos reales** en Firestore (bytes, subcolección `photos`), elegidas con
   `image_picker` (única dependencia nueva acordada), con validación de formato
   y límites y con la configuración y los tipos que guarda Supabase (D10).
3. Tomar al cliente de la sesión (Firebase Auth + perfil `users/{uid}`).
4. Que el propietario vea solo las PQRS de moteles cuyo `ownerId` es su uid.
5. Reglas de seguridad en `firestore.rules` que fuercen la máquina de estados,
   incluido el cierre por vencimiento.
6. Cierre por vencimiento del plazo de confirmación (7 días desde `resolvedAt`).
7. Pruebas del controlador y de la máquina de estados.

## Fuera de alcance

- Vista del administrador (solo lectura, ya existe; solo se verifica que compile).
- Notificaciones al cliente o propietario.
- Procesos en segundo plano, Cloud Functions y plan Blaze.
- Gestor de estado: se sigue con `ChangeNotifier` + `ListenableBuilder`.

## Dependencias con otras ramas/personas

| Con | Por qué |
|---|---|
| `feature_marco` (moteles) | Necesito `motels/{motelId}.ownerId` en Firestore para saber qué moteles son del propietario. La copia en `motels` ya existe en `firestore.rules`; no cambiar su API sin avisar. |
| Autenticación (rama de auth) | Uid y rol del usuario actual (`users/{uid}.role`, `accountStatus`). |
| `feature_daniel` | Escribió el módulo originalmente. Hoy el responsable de esta rama es dueño de todo PQRS, incluido `lib/models/pqrs/`; no hay que coordinar con esa rama. |
| Reservas | No requerida: cualquier cliente activo puede radicar sobre cualquier motel (D4). |

## Inconsistencias detectadas en la especificación

Cada inconsistencia queda con una solución final. La tabla resumen está al
final de la sección.

1. **Nombres de estado en dos idiomas y con sinónimos.** La tabla usa
   Pendiente / En trámite / Solucionado / Cerrada / Rechazado (género
   inconsistente) y el flujo usa `pending`, `in_progress`, `resolved`,
   `closed`, `rejected`. **Solución:** claves en inglés en el código y
   Firestore, etiquetas en español solo en la UI (ya en
   `pqrs_presentation.dart`):

   | Clave Firestore | Enum Dart (ya existe) | Etiqueta UI |
   |---|---|---|
   | `pending` | `PqrsStatus.pending` | Pendiente |
   | `in_progress` | `PqrsStatus.inProgress` | En trámite |
   | `resolved` | `PqrsStatus.resolved` | Solucionada |
   | `closed` | `PqrsStatus.closed` | Cerrada |
   | `rejected` | `PqrsStatus.rejected` | Rechazada |

   El valor guardado usa `snake_case` (`in_progress`) por coincidir con la
   especificación; el enum Dart conserva `inProgress` y se mapea en
   `fromFirestore`/`toFirestore`.
2. **"Responder a propietario" incluye "Solucionada o no" para el cliente.**
   Contradice el flujo: solo el propietario marca `resolved`. **Solución:** se
   elimina ese checkbox. El cliente tiene dos acciones: comentar y "Confirmar
   solución y cerrar" (solo en `resolved`).
3. **Faltan campos en PQRS** (tipo, descripción, nombre del motel, nombre del
   cliente, dueño del motel, id del autor). **Solución:** se agregan al modelo;
   `ownerId` se denormaliza para que la regla de lectura no necesite una
   lectura adicional.
4. **IMÁGENES sin url/ruta y como tabla aparte.** Con Firestore no hace falta
   una tabla de imágenes. **Solución:** las fotos viven en la subcolección
   `pqrs/{pqrsId}/photos`, con `traceId` y `bytes` (decisión D1, ver
   "Almacenamiento de imágenes"); la entrada de trazabilidad solo guarda
   `photoCount`.
5. **Estado en TRAZABILIDAD y en PQRS.** **Solución:** se conservan los dos con
   significados distintos: en PQRS es el estado actual; en la trazabilidad es el
   cambio que provocó esa entrada (`statusChange`, nulo si no cambió).
6. **"cliente_o_propietario" como columna.** **Solución:** `authorRole` +
   `authorId` + `authorName`.
7. **Rechazo sin campo de justificación.** **Solución:** el motivo es el
   `message` obligatorio de la entrada que cambia el estado a `rejected`; el
   cliente lo lee en el timeline. Sin campo extra: evita dos fuentes de verdad.
8. **"Tasa de cerradas por cliente" ambigua.** **Solución (D5):** mide la
   aceptación del cliente: `closed` con `closedBy = client` / (`resolved` +
   `closed`); 0 si el denominador es 0. Complementos:
   - Tasa de solución = (`resolved` + `closed`) / total.
   - Los `rejected` cuentan en el total.
   - Los cierres por vencimiento cuentan como `closed` en la tasa de solución y
     en el denominador, pero no en el numerador de la tasa de cierre por cliente.
9. **Qué pasa si el cliente nunca confirma.** **Solución (D3):** (a) si el
   cliente comenta en `resolved`, la solicitud se reabre a `in_progress` y se
   limpia `resolvedAt`; (b) si pasan 7 días corridos desde `resolvedAt` sin
   respuesta, el propietario puede usar "Cerrar por falta de respuesta". Ver
   "Cierre por vencimiento del plazo de confirmación". Se evita un proceso
   automático para no depender de Cloud Functions ni del plan Blaze.
10. **"Cliente comenta mientras pending/in_progress/resolved".** **Solución:**
    en `pending` e `in_progress` el comentario no cambia el estado; en
    `resolved` reabre a `in_progress`; en `closed` y `rejected` no se puede.
11. **"Estado final" mal definido.** **Solución:** finales son `closed` y
    `rejected`; `resolved` **no** es final (espera al cliente). El código ya lo
    refleja con `isFinal`.
12. **Validación de rol en backend.** **Solución:** ocultar el botón no es
    autorización; las transiciones por rol se aplican en `firestore.rules`
    (matriz abajo).
13. **"El propietario solo ve PQRS de sus moteles"** no puede garantizarse
    filtrando en la app. **Solución:** `ownerId` en el documento y regla de
    lectura.
14. **El cuadro de info difiere por rol** (cliente: Motel; propietario: Cliente
    y Tipo). **Solución:** es solo presentación; se reutilizan los mismos
    widgets con campos distintos, sin impacto en datos.
15. **Quién es "cliente" en la bandeja.** **Solución (D8):** se muestra
    `clientName` (solo nombre, sin correo ni teléfono).
16. **El `id_cliente` puede quedar huérfano** si se anonimiza o borra la
    cuenta. **Solución:** se guarda `clientName` denormalizado; la PQRS sigue
    legible.

Resumen **Inconsistencia → solución adoptada**:

| # | Inconsistencia | Solución adoptada |
|---|---|---|
| 1 | Estados con nombres mezclados | Claves en inglés (`snake_case`), etiquetas en español solo en la UI |
| 2 | Cliente marca "solucionada" | Se elimina; el cliente comenta o confirma y cierra |
| 3 | Faltan campos en PQRS | Se agregan tipo, descripción, nombres, `ownerId`, ids de autor |
| 4 | IMÁGENES sin ruta | Subcolección `photos` con bytes (D1) |
| 5 | Estado duplicado | Estado actual en PQRS; cambio de estado en la traza |
| 6 | Columna "cliente_o_propietario" | `authorRole`, `authorId`, `authorName` |
| 7 | Rechazo sin justificación | Mensaje obligatorio de la traza |
| 8 | Tasa de cerradas ambigua | `closedBy = client` / (`resolved` + `closed`) (D5) |
| 9 | Cliente no confirma | Reapertura al comentar y cierre por vencimiento a los 7 días (D3) |
| 10 | Comentario según estado | Sin cambio en curso; reabre en `resolved`; bloqueado en finales |
| 11 | Estado final ambiguo | `closed` y `rejected` |
| 12 | Rol en backend | Reglas de Firestore por rol y transición |
| 13 | Propietario ve solo lo suyo | `ownerId` y regla de lectura |
| 14 | Info distinta por rol | Mismos widgets, solo presentación |
| 15 | Datos del cliente en bandeja | Solo `clientName` (D8) |
| 16 | `id_cliente` huérfano | `clientName` denormalizado |

Simplificación justificada: no se agrega un campo de justificación de rechazo
ni un estado nuevo para la reapertura; con la traza y el estado existente
alcanza y hay menos reglas que mantener.

## Casos eliminados / agregados y justificación

| Caso | Decisión | Justificación |
|---|---|---|
| Cliente marca "solucionada o no" | Eliminado | Contradice el flujo; solo propietario resuelve. |
| Tabla IMÁGENES separada | Eliminado | Las fotos van en la subcolección `photos`; la traza solo guarda `photoCount`. |
| Cierre automático por proceso programado | No incluido | Exigiría Cloud Functions y plan Blaze; se reemplaza por el cierre por vencimiento. |
| Cierre por vencimiento (propietario, 7 días) | Agregado | Resuelve "el cliente nunca confirma" con reglas de Firestore y sin infraestructura extra. |
| Reapertura si el cliente comenta en `resolved` | Agregado | Cierra el hueco de "cliente no conforme" sin un estado nuevo. |
| Notificaciones | No incluido | Fuera de alcance, ya excluidas en otras ramas. |
| Edición o borrado de PQRS | No incluido | La trazabilidad debe ser inmutable (auditoría). |
| Validación de longitud de textos | Agregado | Evita documentos enormes y es trivial en reglas. |
| Cliente no puede radicar sobre un motel inexistente | Agregado | Integridad mínima. |
| Reglas Firestore por rol y transición | Agregado | Requisito del CLAUDE.md (validación en backend). |
| Vista del administrador | Fuera de esta spec | Ya implementada; solo se verifica que compile. |
| Pruebas de controlador | Agregado | Hoy no hay ninguna. |
| Orden por fecha en bandeja | Agregado | Más recientes primero (ya lo hace el store). |

## Modelo de datos (Firestore)

Constante propuesta: `FirestoreCollections.pqrs = 'pqrs'`. La trazabilidad es
una **subcolección** `pqrs/{pqrsId}/traces/{traceId}`: permite añadir entradas
sin reescribir el documento y regla propia por entrada. Las fotos van en la
subcolección `pqrs/{pqrsId}/photos/{photoId}` (ver "Almacenamiento de
imágenes").

### `pqrs/{pqrsId}`

| Campo | Tipo | Notas |
|---|---|---|
| `clientId` | string | uid del cliente; debe ser `request.auth.uid` al crear. |
| `clientName` | string | Denormalizado (máx. 100). |
| `motelId` | string | Id del motel (`motels/{motelId}`). |
| `motelName` | string | Denormalizado, solo para mostrar. |
| `ownerId` | string | uid del propietario del motel, copiado de `motels/{motelId}.ownerId`. Permite regla de lectura sin `get()` extra. |
| `type` | string | `code` del tipo (`peticion`, `queja`, `reclamo`, `sugerencia`), tomado del catálogo `pqrs_types` de Supabase. Nunca se guarda el nombre visible. Las reglas validan la lista fija de códigos. |
| `subject` | string | 3 a 100 caracteres. |
| `description` | string | 10 a 1000 caracteres. |
| `status` | string | Estado actual: `pending`, `in_progress`, `resolved`, `closed`, `rejected`. |
| `resolvedAt` | timestamp o ausente | Se fija (`request.time`) al pasar a `resolved`. Se elimina si la solicitud vuelve a `in_progress`. Se conserva al pasar a `closed`. Es la base del plazo de 7 días. |
| `closedBy` | string o ausente | Solo con `status = closed`: `client` (confirmó) u `owner_timeout` (cierre por vencimiento). Las solicitudes cerradas sin este campo se cuentan como `client`. |
| `photoCount` | int | Número de fotos (0 a 3) guardadas en `pqrs/{pqrsId}/photos`. Ver D1 y la sección "Almacenamiento de imágenes". |
| `createdAt` | timestamp | `request.time`. |
| `updatedAt` | timestamp | `request.time` en cada cambio. |

### `pqrs/{pqrsId}/traces/{traceId}`

| Campo | Tipo | Notas |
|---|---|---|
| `authorId` | string | uid del autor (= `request.auth.uid`). |
| `authorRole` | string | `client` u `owner`. (`systemAdmin` existe en el enum pero no escribe en esta spec.) |
| `authorName` | string | Denormalizado. |
| `message` | string | 1 a 1000 caracteres. Obligatorio; en `rejected` es la justificación; en el cierre por vencimiento es el texto fijo "Cerrada por vencimiento del plazo de confirmación". |
| `statusChange` | string o ausente | Nuevo estado si la entrada lo provocó; nulo si no. |
| `photoCount` | int | 0 a 3 fotos de esta entrada, guardadas en `pqrs/{pqrsId}/photos` con `traceId` igual al id de esta entrada. Ver "Almacenamiento de imágenes". |
| `createdAt` | timestamp | `request.time`. |

No se guardan URLs privadas ni datos de prueba en el repositorio.

## Máquina de estados

Transiciones permitidas (todo lo demás se rechaza):

| Desde | Hacia | Rol | Disparador | Entrada de trazabilidad |
|---|---|---|---|---|
| (nuevo) | `pending` | Cliente | Radica | No (los datos iniciales están en el documento) |
| `pending` | `in_progress` | Propietario | Registrar avance (comentario) | Sí, con `statusChange=in_progress` |
| `pending` | `resolved` | Propietario | Registrar avance + "Marcar como solucionada" | Sí; fija `resolvedAt` |
| `pending` | `rejected` | Propietario | Rechazar con justificación | Sí |
| `in_progress` | `in_progress` | Propietario | Nuevo avance | Sí, sin `statusChange` |
| `in_progress` | `resolved` | Propietario | Marcar como solucionada | Sí; fija `resolvedAt` |
| `in_progress` | `rejected` | Propietario | Rechazar con justificación | Sí |
| `pending` / `in_progress` | igual | Cliente | Comenta | Sí, sin `statusChange` |
| `resolved` | `closed` | Cliente | "Confirmar solución y cerrar" | Sí; `closedBy = client` |
| `resolved` | `in_progress` | Cliente | Comenta ("no quedó resuelta") | Sí, `statusChange=in_progress`; se elimina `resolvedAt` (D2) |
| `resolved` | `closed` | Propietario | "Cerrar por falta de respuesta", solo si `request.time > resolvedAt + 7 días` | Sí, mensaje fijo; `closedBy = owner_timeout` (D3) |
| `resolved` | `resolved` | Propietario | Nuevo mensaje sin cambiar estado | **No permitido**: ya espera al cliente |
| `closed`, `rejected` | cualquiera | cualquiera | cualquiera | **Prohibido** |

Matriz por rol:

| Acción | Cliente (dueño) | Propietario (del motel) | Otro cliente/propietario | Administrador |
|---|---|---|---|---|
| Leer PQRS y trazas | Sí, las suyas | Sí, las de sus moteles | No | Sí (todas) |
| Crear PQRS | Sí, a su nombre | No | No | No |
| Comentar | Sí (no final; en `resolved` reabre) | Sí (no final, no `resolved`) | No | No |
| Resolver / rechazar | No | Sí | No | No |
| Cerrar confirmando | Sí (solo `resolved`) | No | No | No |
| Cerrar por vencimiento | No | Sí (solo `resolved` con plazo de 7 días vencido) | No | No |
| Editar o borrar PQRS/trazas | No | No | No | No |

Nota: el código actual permite al propietario comentar sobre `resolved`
(`addUpdate` solo bloquea estados finales), no reabre con el comentario del
cliente y no tiene cierre por vencimiento. La implementación debe alinearse con
esta tabla.

## Reglas de validación

Formulario (cliente):

- Motel: obligatorio; debe existir y estar activo.
- Tipo: obligatorio (`PqrsType`); la lista visible sale de `pqrs_types` y solo
  se guarda su `code`.
- Asunto: obligatorio, 3 a 100 caracteres, sin solo espacios.
- Descripción: obligatoria, 10 a 1000 caracteres.
- Imágenes: opcionales, máx. 3.
- Cliente: nunca viene del formulario, sale de la sesión.

Avances (propietario y cliente): mensaje obligatorio 1 a 1000; "Marcar como
solucionada" y "Rechazar" son excluyentes; rechazo exige justificación no vacía
(mínimo 10 caracteres, igual que el rechazo de propietarios en las reglas).

Reglas de Firestore (resumen de lo que debe forzar el backend):

- Crear `pqrs`: cliente activo, `clientId == auth.uid`, `status == 'pending'`,
  `ownerId` igual al `ownerId` de `motels/{motelId}`, campos y tamaños válidos,
  sin `resolvedAt` ni `closedBy`, `createdAt/updatedAt == request.time`.
- Actualizar `pqrs`: solo `status`, `updatedAt`, `resolvedAt` y `closedBy`; la
  transición debe estar en la tabla y el rol correcto (función
  `isValidPqrsTransition(prev, next, role)`, mismo patrón que
  `isValidReservationTransition`). Al pasar a `resolved` se exige
  `resolvedAt == request.time`; al volver a `in_progress` se exige que
  `resolvedAt` desaparezca; al pasar a `closed` se exige `closedBy` coherente
  con quien escribe (`client` para el cliente, `owner_timeout` para el
  propietario).
- Cierre por vencimiento: el propietario solo puede pasar de `resolved` a
  `closed` si `request.time > resource.data.resolvedAt + duration.value(7, 'd')`
  (las reglas permiten sumar una duración a un timestamp); la traza de ese
  cierre debe llevar `authorRole = owner` y el mensaje fijo.
- Crear traza: autor = `auth.uid`, rol coherente con el rol del perfil, PQRS no
  en estado final, y si `statusChange` existe debe coincidir con el `status`
  nuevo del documento padre en el mismo lote (`getAfter`).
- Sin `update` ni `delete` en trazas ni borrado de `pqrs`.
- Orden final: agregar el bloque `match /pqrs/...` **arriba** de la regla
  denegar-todo, como indica el comentario del propio archivo.

Clave de implementación: la creación de traza y el cambio de estado deben ir en
**un solo `WriteBatch`** para que no queden desincronizados.

## Cierre por vencimiento del plazo de confirmación

**Problema:** un cliente puede no confirmar nunca una solicitud `resolved`, y
queda abierta para siempre (inconsistencia 9).

**Diseño:**
1. Al pasar a `resolved` se guarda `resolvedAt`. Si el cliente comenta y la
   solicitud vuelve a `in_progress`, `resolvedAt` se elimina; si el propietario
   la resuelve otra vez, se fija uno nuevo.
2. El detalle del cliente muestra, de forma informativa: "Si no confirmas antes
   del <fecha>, el propietario podrá cerrarla" (fecha = `resolvedAt` + 7 días).
3. Pasados 7 días corridos desde `resolvedAt` sin respuesta del cliente, el
   propietario ve el botón "Cerrar por falta de respuesta" (visible solo cuando
   venció el plazo). Al usarlo, la solicitud pasa a `closed` con
   `closedBy = owner_timeout` y se crea una entrada de trazabilidad con el
   mensaje fijo "Cerrada por vencimiento del plazo de confirmación".
4. Las reglas de Firestore lo exigen: ver "Reglas de validación". La app
   decide la visibilidad del botón con la hora del dispositivo, pero la
   validación real es la hora del servidor (`request.time`).

**Por qué no necesita Cloud Functions, plan Blaze ni procesos en segundo
plano:** no hay nada que se ejecute solo; quien actúa es el propietario y las
reglas, que ya existen en el plan gratuito, comprueban que el plazo venció.

**Plazo:** 7 días como constante en la app y escrito en las reglas. No va en
Supabase porque las reglas no pueden leerlo (D14); cambiarlo exige editar ambos
lados.

**Límite:** el cierre ocurre **cuando alguien actúa**, no solo por el paso del
tiempo. Una solicitud vencida sigue en `resolved` hasta que el propietario use
el botón. La bandeja del propietario puede mostrar un indicador de "plazo
vencido" en esas solicitudes.

**Estadísticas:** un cierre por vencimiento cuenta como `closed` (tasa de
solución y conteo de "Cerrada"). La "tasa de cierre por cliente" (D5) solo
cuenta como numerador los `closed` con `closedBy = client`; los cierres por
vencimiento quedan en el denominador (`resolved` + `closed`). El panel puede
mostrar además el conteo "Cerradas por vencimiento". La fórmula de D5 no cambia
en el denominador; solo se precisa qué cierres cuentan en el numerador.

## Escenarios (Gherkin)

### Feature: Radicar y seguir mis PQRS (Cliente)

  Scenario: Cliente radica una PQRS válida
    Given un cliente autenticado en "Mis PQRS"
    When completa Motel, Tipo, Asunto y Descripción, adjunta fotos opcionales y presiona "Enviar"
    Then la PQRS se guarda en Firestore con estado "pending" y el uid del cliente de la sesión
    And aparece primera en "Mis solicitudes" con el nombre del motel y la fecha de creación

  Scenario: Formulario incompleto o fuera de rango
    Given un cliente en el formulario de nueva solicitud
    When deja vacío el asunto o la descripción, o no elige motel o tipo
    Then ve el mensaje de validación bajo cada campo y no se guarda nada

  Scenario: Cliente sin sesión intenta radicar
    Given una sesión expirada o inexistente
    When intenta guardar una PQRS
    Then ve un mensaje de que debe iniciar sesión y no se crea la PQRS

  Scenario: Cliente ve solo sus solicitudes
    Given dos clientes con PQRS distintas
    When el primero abre "Mis solicitudes"
    Then ve solo las suyas, ordenadas de la más reciente a la más antigua

  Scenario: Estado vacío del cliente
    Given un cliente sin ninguna PQRS
    When abre "Mis solicitudes"
    Then ve un mensaje "Aún no tienes solicitudes" con un acceso a "Nueva solicitud"

  Scenario: Cliente comenta mientras la solicitud está en curso
    Given una PQRS propia en "pending" o "in_progress"
    When escribe un comentario con fotos opcionales y lo envía
    Then el comentario aparece al final del timeline con su fecha
    And el estado no cambia

  Scenario: Cliente comenta sobre una solicitud solucionada
    Given una PQRS propia en "resolved"
    When escribe un comentario indicando que no quedó resuelta
    Then la PQRS vuelve a "in_progress" y el cambio queda en el timeline
    And se elimina resolvedAt del documento
    And el propietario la ve de nuevo en su bandeja como "En trámite"

  Scenario: Cliente ve hasta cuándo puede confirmar
    Given una PQRS propia en "resolved" con resolvedAt
    When el cliente abre el detalle
    Then ve "Si no confirmas antes del <fecha>, el propietario podrá cerrarla", con fecha igual a resolvedAt más 7 días
    And es solo un aviso informativo

  Scenario: Cliente confirma y cierra
    Given una PQRS propia en "resolved"
    When presiona "Confirmar solución y cerrar"
    Then la PQRS pasa a "closed" con closedBy = client y queda registrada la entrada en el timeline
    And ya no admite comentarios

  Scenario: Cliente confirma antes de que venza el plazo
    Given una PQRS en "resolved" con menos de 7 días desde resolvedAt
    When el cliente presiona "Confirmar solución y cerrar"
    Then la PQRS pasa a "closed" con closedBy = client
    And el propietario no necesita usar el cierre por vencimiento

  Scenario: Cliente no puede cerrar antes de tiempo
    Given una PQRS propia en "pending" o "in_progress"
    When se intenta cerrarla
    Then el botón "Confirmar solución y cerrar" no se muestra
    And si se fuerza desde fuera de la UI, las reglas de Firestore lo rechazan

  Scenario: Cliente intenta ver o modificar la PQRS de otro
    Given una PQRS de otro cliente
    When intenta leerla o escribir en ella
    Then Firestore deniega la operación

### Feature: Atender PQRS de mis moteles (Propietario)

  Scenario: Propietario ve solo la bandeja de sus moteles
    Given un propietario activo con dos moteles y PQRS de otros moteles en la base
    When abre "PQRS Mi Motel"
    Then ve solo las PQRS cuyo ownerId es su uid
    And cada fila muestra Asunto, Descripción, Tipo, Fecha, Cliente y Estado

  Scenario: Mi desempeño
    Given un propietario con PQRS en varios estados
    When abre el panel "Mi desempeño"
    Then ve Total, Tasa de solución, Tasa de cierre por cliente y el conteo de Pendiente, En trámite, Solucionada, Cerrada (con las cerradas por vencimiento aparte) y Rechazada
    And con cero solicitudes las tasas se muestran en 0 % sin error

  Scenario: Filtrar la bandeja por estado
    Given una bandeja con PQRS en varios estados
    When el propietario toca el botón de un estado
    Then la lista muestra solo ese estado
    When toca "Todas"
    Then vuelve a ver todas

  Scenario: Filtro sin resultados
    Given una bandeja sin PQRS en el estado elegido
    When el propietario aplica ese filtro
    Then ve un estado vacío "No hay solicitudes con este estado"

  Scenario: Estado vacío de la bandeja
    Given un propietario sin ninguna PQRS en sus moteles
    When abre la bandeja
    Then ve un estado vacío informativo y el panel de desempeño en cero

  Scenario: Primer avance activa la solicitud
    Given una PQRS en "pending"
    When el propietario registra un avance con mensaje
    Then la PQRS pasa automáticamente a "in_progress"
    And la entrada del timeline muestra el cambio de estado

  Scenario: Propietario resuelve
    Given una PQRS en "pending" o "in_progress"
    When registra un avance con foto opcional y marca "Marcar como solucionada"
    Then la PQRS pasa a "resolved" y queda a la espera del cliente
    And se guarda resolvedAt con la hora del servidor

  Scenario: Propietario cierra por vencimiento del plazo
    Given una PQRS en "resolved" con más de 7 días corridos desde resolvedAt y sin respuesta del cliente
    When el propietario presiona "Cerrar por falta de respuesta"
    Then la PQRS pasa a "closed" con closedBy = owner_timeout
    And el timeline muestra "Cerrada por vencimiento del plazo de confirmación"
    And cuenta como "Cerrada" en el panel, pero no en la tasa de cierre por cliente

  Scenario: Plazo no vencido
    Given una PQRS en "resolved" con menos de 7 días desde resolvedAt
    When el propietario abre el detalle
    Then el botón "Cerrar por falta de respuesta" no se muestra
    And si se fuerza desde fuera de la UI, las reglas de Firestore lo rechazan

  Scenario: Cierre por vencimiento sin conexión
    Given una PQRS vencida en "resolved" y un propietario sin conexión
    When presiona "Cerrar por falta de respuesta"
    Then la acción queda "pending_sync" en la cola local
    And al sincronizar, Firestore la acepta solo si el plazo venció con la hora del servidor y el cliente no respondió; si no, queda "failed" con el motivo

  Scenario: Propietario rechaza con justificación
    Given una PQRS en "pending" o "in_progress"
    When presiona "Rechazar", escribe una justificación y confirma
    Then la PQRS pasa a "rejected", estado final
    And la justificación es visible para el cliente en el timeline

  Scenario: Rechazo sin justificación
    Given el diálogo de rechazo abierto
    When confirma con la justificación vacía o menor al mínimo
    Then ve un error de validación y la PQRS no cambia

  Scenario: Propietario intenta atender una PQRS ajena
    Given una PQRS de un motel que no es suyo
    When intenta leerla o modificarla
    Then Firestore deniega la operación

### Feature: Estados finales y timeline

  Scenario: PQRS en estado final
    Given una PQRS en "closed" o "rejected"
    When cualquier actor abre el detalle
    Then ve un aviso "Esta solicitud está cerrada" (o "rechazada") y no hay caja de texto ni botones de acción
    And Firestore rechaza cualquier escritura sobre ella

  Scenario: Timeline completo y cronológico
    Given una PQRS con comentarios, fotos y cambios de estado
    When el cliente o el propietario abre el detalle
    Then ve todas las entradas de la más antigua a la más reciente
    And cada una muestra autor, rol, fecha, mensaje, fotos y, si aplica, el cambio de estado

  Scenario: Detalle de una PQRS inexistente
    Given un id que no existe o que el usuario no puede leer
    When abre el detalle
    Then ve un mensaje de "Solicitud no encontrada" y puede volver al listado

### Feature: Errores

  Scenario: Falla la red al cargar
    Given que Firestore no responde
    When el usuario abre su lista de PQRS
    Then ve un mensaje de error claro con la opción "Reintentar"
    And la app no se cierra

  Scenario: Falla la red al enviar un comentario
    Given un comentario escrito
    When falla el guardado
    Then el texto se conserva en la caja y se informa el error

  Scenario: Doble transición simultánea
    Given que cliente y propietario actúan casi a la vez sobre la misma PQRS
    When la segunda escritura llega con el estado ya cambiado
    Then la regla o la transacción la rechaza y la app muestra el estado actualizado

## Mapa de archivos propuesto (dentro de la estructura provisional)

Sin reorganizar `lib/`. Se reutiliza lo que existe y se añade lo mínimo:

| Archivo | Acción |
|---|---|
| `lib/models/pqrs/pqrs.dart` | Modificar: añadir `ownerId`, `resolvedAt` y `closedBy` a `PqrsRequest`, `authorId` a `PqrsTraceEntry`; ajustar `closureRate` (numerador solo `closedBy = client`, D5), conteo de cierres por vencimiento y `canBeClosedByOwnerTimeout` (plazo de 7 días como constante). Verificar que la vista del administrador compile. |
| `lib/views/pqrs/pqrs_page.dart` | Modificar: quitar el selector de perfil de prueba cuando haya sesión (D7). |
| `lib/models/pqrs/pqrs_store.dart` | Mantener solo como datos semilla/pruebas; deja de ser la fuente. |
| `lib/service/firebase/firestore_collections.dart` | Añadir `pqrs = 'pqrs'` y nombre de subcolección. |
| `lib/database/model/pqrs/pqrs_firestore_document.dart` | Nuevo: `fromFirestore`/`toFirestore` y mapeo `in_progress` a `inProgress`. |
| `lib/database/repository/pqrs/pqrs_repository.dart` | Nuevo: contrato (crear, listar por cliente, listar por propietario, detalle, agregar traza con cambio de estado). |
| `lib/database/repository/pqrs/firestore_pqrs_repository.dart` | Nuevo: implementación con `WriteBatch`. |
| `lib/controllers/pqrs/pqrs_controller.dart` | Modificar: recibir el repositorio por constructor y el uid/rol de sesión; eliminar singleton cuando las vistas lo permitan. |
| `lib/views/pqrs/**` | Modificar: quitar `pqrsCurrentClientId`/`pqrsCurrentMotelId`; estados de carga y error. |
| `lib/widgets/pqrs/**` | Reutilizar. Añadir botón "Confirmar solución y cerrar", botón "Cerrar por falta de respuesta" (solo propietario, solo con plazo vencido), aviso informativo al cliente con la fecha límite y aviso de estado final si faltan. |
| `firestore.rules` | Añadir bloque `pqrs`, `pqrs/{id}/traces` y `pqrs/{id}/photos` arriba de la regla denegar-todo, con la regla del cierre por vencimiento (`duration.value(7, 'd')`). |
| `pubspec.yaml` | Agregar solo `image_picker` (única dependencia nueva acordada, D1). |
| `test/controllers/pqrs/`, `test/models/pqrs/` | Nuevo: transiciones, estadísticas, repositorio falso en memoria. |
| `lib/database/model/pqrs/pqrs_cache_entry.dart`, `pqrs_trace_cache_entry.dart`, `pqrs_outbox_entry.dart`, `pqrs_outbox_photo.dart` | Nuevo: entidades Floor (ver "Persistencia local"). |
| `lib/database/repository/pqrs/pqrs_dao.dart` | Nuevo: `@dao` con las 4 tablas (mismo estilo que `MotelDao`). |
| `lib/database/repository/pqrs/synced_pqrs_repository.dart` | Nuevo: implementa `PqrsRepository` combinando DAO + `FirestorePqrsRepository` (mismo patrón que `SyncedBookingRepository`). |
| `lib/database/model/image_format/allowed_image_format.dart` | Nuevo: entidad Floor y `fromJson` (firmas como JSON) de `allowed_image_formats`. |
| `lib/database/repository/image_format/allowed_image_format_dao.dart` | Nuevo: DAO de la caché de formatos. |
| `lib/database/repository/image_format/supabase_pqrs_validation_repository.dart` | Nuevo: consulta REST con `http` de `allowed_image_formats` y `pqrs_settings`; caché Floor (formatos) y `shared_preferences` (configuración); copia el patrón de `PhoneCountryCodeRepository` pero network first. |
| `lib/database/model/pqrs_type/pqrs_type_entry.dart`, `lib/database/repository/pqrs_type/pqrs_type_dao.dart` | Nuevo: entidad Floor y DAO de la caché de `pqrs_types` (nombre distinto del enum `PqrsType` para no chocar). |
| `lib/database/repository/pqrs_type/supabase_pqrs_type_repository.dart` | Nuevo: consulta REST con `http` de `pqrs_types`, caché y valores por defecto; descarta `code` que no existen en el enum `PqrsType`. |
| `lib/utils/pqrs_response_date.dart` | Nuevo: función pura que suma `response_days` hábiles (lunes a viernes, sin festivos); solo informativa. |
| `lib/models/pqrs/pqrs_settings.dart` | Nuevo: modelo Dart puro de `pqrs_settings` con los valores por defecto. |
| `lib/utils/pqrs_image_validator.dart` | Nuevo: función pura (MIME o extensión, firmas con offset+hex, tamaño, cantidad); sin red ni Flutter, probable con bytes de ejemplo. |
| `lib/database/app_database.dart` (y `.g.dart` regenerado) | Modificar: registrar entidades/DAOs y `migration17To18`. Archivo compartido: coordinar con el equipo (D12). |
| `supabase/migrations/202611100001_create_pqrs_config.sql` | Existente: tablas `allowed_image_formats`, `pqrs_settings` y `pqrs_types` con RLS de solo lectura; idempotente. Lo aplica el equipo en Supabase. |
| `test/repositories/pqrs/`, `test/utils/pqrs_image_validator_test.dart` | Nuevo: cola, estados de sincronización, validador. |

La ubicación de `lib/database/repository/<feature>/` sigue el patrón ya usado
por moteles y reseñas (ver `feature_marco.feature.md`).

## Criterios de aceptación

1. Una PQRS radicada aparece en Firestore con `status = pending` y `clientId`
   igual al uid autenticado; ninguna vista usa constantes de sesión.
2. Las transiciones de la tabla funcionan y cualquier otra es rechazada tanto
   en el controlador como en `firestore.rules` (probado con el emulador o,
   como mínimo, revisión manual de las reglas).
3. Un propietario no puede leer PQRS de moteles ajenos; un cliente no puede
   leer PQRS ajenas.
4. `closed` y `rejected` no admiten escrituras.
5. El rechazo exige justificación visible en el timeline.
6. Estados vacío, de carga y de error visibles en las listas de ambos roles.
7. Panel "Mi desempeño" con las fórmulas acordadas y sin división por cero.
8. Pruebas unitarias de las transiciones y de `PqrsStats`; `flutter analyze`
   sin nuevos avisos en los archivos tocados.
9. Cero colores hexadecimales, radios o duraciones sueltos; nombres técnicos
   en inglés, textos visibles en español; vistas sin llamadas directas a
   Firestore.
10. Sin conexión se puede radicar, comentar y avanzar: la acción queda visible
    con estado de sincronización y se envía al volver la red; si el servidor la
    rechaza, el usuario lo ve con el motivo y puede descartar o reintentar.
11. Leer sin red muestra la última copia local con un aviso de "datos
    guardados"; Firestore siempre manda al reconectar.
12. Una foto con formato no permitido o desactivado (`is_active = false`), con firma que no coincide o por encima de los límites se rechaza antes de guardar; sin Supabase ni caché se usan los valores por defecto (JPEG/PNG/WebP, 900 KB, 3 fotos, calidad 60, 1280 px).
13. Las reglas de Firestore mantienen tipo, tamaño y cantidad escritos a mano
    (no pueden leer Supabase) y son la validación real del servidor.
14. Cierre por vencimiento: `resolvedAt` se fija al pasar a `resolved` y se
    elimina al reabrir; pasados 7 días corridos el propietario ve "Cerrar por
    falta de respuesta" y la solicitud pasa a `closed` con `closedBy =
    owner_timeout` y la entrada de trazabilidad fija; antes del plazo el botón
    no se muestra y las reglas lo rechazan; el cliente ve la fecha límite
    informativa; la tasa de cierre por cliente cuenta solo `closedBy = client`.
15. El formulario lista los tipos activos de `pqrs_types` ordenados por
    `sort_order` (con caché y los cuatro tipos por defecto sin red), oculta
    las fotos si `allows_photos` es `false` y guarda solo el `code` en `type`;
    las reglas de Firestore rechazan cualquier `code` fuera de la lista fija.
16. La fecha estimada de respuesta (fecha de creación más `response_days`
    hábiles, lunes a viernes sin festivos) se muestra como dato informativo y
    no se guarda ni cambia estados.
17. Pruebas de: transición de estados de la cola (`pending_sync`, `synced`,
    `failed`), el validador de imágenes (firmas, MIME nulo, límites), el
    cálculo de la fecha estimada, la regla del cierre por vencimiento (con
    plazo vencido y no vencido), el mapeo `code` a `PqrsType` (con un `code`
    desconocido) y los repositorios de configuración con HTTP simulado.

## Almacenamiento de imágenes (decisión D1)

**Decisión:** las fotos se guardan en Firestore como bytes (`Blob`) en la
subcolección `pqrs/{pqrsId}/photos/{photoId}`. No se usa Firebase Storage ni
servicios externos (Supabase, R2, Cloudinary).

**Por qué:** demo universitaria que debe quedarse en el plan Spark (Storage
exige Blaze); un solo proveedor y un solo juego de reglas; la
PQRS y sus fotos se escriben en un mismo `WriteBatch` (todo o nada, sin fotos
huérfanas); la subcolección evita descargar fotos al listar. Se descartó
base64 dentro del documento (pesado, límite de 1 MiB).

**Cómo:**
- Máximo 3 fotos por entrada (radicación, comentario o avance), comprimidas en
  el cliente (`imageQuality` ~60, `maxWidth` ~1280); cada una < 900 KB.
- Campos de `photos/{photoId}`: `bytes` (Blob), `mimeType` (`image/jpeg`,
  `image/png` o `image/webp`), `traceId` (entrada a la que pertenece),
  `authorId`, `createdAt`.
- IDs de foto fijos por entrada (`<traceId>_1` a `<traceId>_3`) para que las
  reglas limiten la cantidad.
- Las fotos son inmutables: se crean junto con su entrada y no se editan ni
  borran.
- Se cargan solo en el detalle, nunca en el listado.
- Reglas de Firestore: validan autor, tamaño, tipo de imagen y que el
  solicitante pueda ver la PQRS (cliente dueño u `ownerId` del motel).
- Límites: 1 MiB por documento y cuotas Spark (1 GiB, 50k lecturas/día). Si
  pasa a producción, el equipo acordó mover las fotos a un bucket y guardar
  solo la ruta.

**Adaptaciones al proyecto MACHUCO** (el texto recibido no encaja tal cual):
- Roles: habla de "ciudadano" y "admin" que cambia el estado. En MACHUCO los
  roles son Cliente y Propietario; **el propietario** cambia el estado y el
  cliente solo cierra (máquina de estados de este documento). El admin no
  escribe en PQRS (D9). Se omite la colección `admins/{uid}`.
- El texto dice "las fotos solo se crean con la PQRS", pero la especificación
  exige fotos también en comentarios y avances. Se permite una foto-lote por
  cada entrada de trazabilidad, siempre inmutable.
- Nombres técnicos en inglés (`photos`, `bytes`, `ownerId`, `clientId`), no
  `fotos` ni `usuarioId`.
- `image_picker` es la única dependencia nueva acordada (2026-11-10).

**Escenarios clave:**
```gherkin
Escenario: Radicar con 0 a 3 fotos válidas
  Dado un cliente autenticado
  Cuando radica una PQRS con 2 fotos válidas
  Entonces la PQRS, su primera entrada y las 2 fotos se guardan en un solo WriteBatch

Escenario: Foto inválida
  Cuando adjunta una foto de 1 MB, de tipo no permitido, o una cuarta foto
  Entonces se rechaza y no se guarda nada

Escenario: Falla de conexión al guardar
  Entonces no queda ninguna PQRS ni foto a medias en Firestore (el lote es atómico)
  Y la solicitud queda en la cola local "pending_sync" hasta poder enviarse (ver "Persistencia local y trabajo sin conexión")

Escenario: Acceso ajeno
  Dado un cliente que no es dueño de la PQRS
  Entonces no puede leer la PQRS ni sus fotos, ni cambiar su estado
```

## Persistencia local y trabajo sin conexión (Floor + Firestore)

**Principio:** Firestore es la base principal y manda siempre; SQLite (Floor)
es solo caché de lectura y cola de envío. Lo que decidió el equipo
(`docs/decisions_log.md`, 2026-10-27 y 2026-10-06) ya cubre esto: no se
introduce ninguna tecnología nueva.

### Qué ya existe y se reutiliza

| Pieza | Dónde | Cómo se aprovecha |
|---|---|---|
| Base Floor `AppDatabase`, **versión 17** hoy | `lib/database/app_database.dart` | Se agregan entidades y una migración 17 a 18 (ver más abajo). |
| Migraciones con `CREATE TABLE IF NOT EXISTS` idempotente | `migration14To15` a `migration16To17` | Mismo estilo; evita choques entre ramas. |
| DAOs como caché de datos remotos | `MotelDao` (`replaceAll`), `PhoneCountryCodeDao` | Mismo patrón para `PqrsDao`. |
| Repositorio "sincronizado" Firestore + local | `SyncedBookingRepository` (`lib/repositories/booking/`) | Mismo patrón: escribir local, empujar a Firestore, reintentar. **Su limitación se corrige aquí:** guarda lo no sincronizado solo en memoria (`_unsynced`), por lo que un reinicio lo olvida; en PQRS la cola vive en SQLite. |
| Resolución de conflictos "lo local sin sincronizar gana en pantalla" en reservas | `_pull` | En PQRS se invierte: **Firestore manda** (más simple y seguro por la máquina de estados). |
| `shared_preferences` vía `LocalPreferencesService` | `lib/service/storage/` | Solo para datos sueltos (p. ej. fecha del último refresco); no para la cola. |
| Conectividad | No hay paquete `connectivity`; las ramas detectan la red por el fallo de la llamada (`catch`). | Se hace igual: no se agrega dependencia. Los reintentos ocurren al abrir la pantalla, al hacer "pull to refresh" y tras cada nueva acción. |

### Tablas Floor propuestas

| Tabla | Para qué | Campos clave |
|---|---|---|
| `pqrs_cache` | Copia de la última lectura de `pqrs/{id}` | `id`, `clientId`, `ownerId`, `motelId`, `motelName`, `clientName`, `type`, `subject`, `description`, `status`, `resolvedAt`, `closedBy`, `photoCount`, `createdAt`, `updatedAt` (todos como TEXT/INTEGER; fechas en epoch). |
| `pqrs_trace_cache` | Copia de `traces` | `id`, `pqrsId`, `authorId`, `authorRole`, `authorName`, `message`, `statusChange`, `photoCount`, `createdAt`. |
| `pqrs_outbox` | Cola de acciones pendientes de enviar | `id` (el `traceId` generado en el cliente), `pqrsId`, `action` (`create`, `comment`, `advance`, `resolve`, `reject`, `close`), `payload` (JSON del documento y la traza), `syncStatus`, `errorMessage`, `createdAt`, `attempts`. |
| `pqrs_outbox_photo` | Fotos de una acción pendiente | `id` (`<traceId>_1..3`), `outboxId`, `mimeType`, `bytes` (BLOB). |
| `pqrs_types` | Caché del catálogo de tipos de Supabase | `id`, `code`, `name`, `description`, `responseDays`, `allowsPhotos`, `sortOrder`, `isActive`. Ver "Catálogo de tipos de PQRS (`pqrs_types`)". |
| `allowed_image_formats` | Caché del maestro de Supabase | `id`, `mimeType`, `extensions` y `signatures` (JSON), `maxSizeBytes`, `isActive`. La configuración `pqrs_settings` va en `shared_preferences`. Ver "Validación de imágenes con configuración en Supabase". |

**Fotos: ¿bytes en SQLite?** Solo para la cola, no como caché general:
- En la cola **sí**: sin red la foto no puede ir a ningún otro lado y es corta
  vida (se borra al sincronizar). Cada foto va en **su propia fila** (máx.
  900 KB) y no en una columna de la fila de la acción: en Android una fila
  mayor a ~2 MB falla al leerse con sqflite (límite de la ventana de cursor),
  y 3 fotos podrían superarlo.
- Como caché de lectura **no**: el detalle ya las baja de Firestore bajo
  demanda; guardarlas inflaría la base. Sin red una foto ya enviada puede no
  mostrarse (placeholder) y es aceptable para una demo.

### Estados de sincronización (solo locales)

`syncStatus` existe solo en `pqrs_outbox`; **no se guarda en Firestore**.

| Estado | Significado | Qué ve el usuario |
|---|---|---|
| `pending_sync` | Guardada en el dispositivo, aún no confirmada por Firestore | Marca "Pendiente de envío" en la tarjeta o entrada del timeline. |
| `synced` | Firestore confirmó el lote; la fila se borra de la cola y el dato llega por la caché | Sin marca. |
| `failed` | Firestore rechazó el lote (reglas, estado cambió, validación) | "No se pudo enviar", con motivo, y botones "Reintentar" y "Descartar". |

Un fallo de red **no** pasa a `failed`: se queda en `pending_sync` y se
reintenta. Solo un rechazo del servidor (`permission-denied`, `failed-precondition`)
pasa a `failed`; así no se pierden acciones por una caída de internet.

### Estrategia de lectura

1. La vista pide la lista al repositorio; este devuelve **primero** la caché
   (rápido, funciona sin red) y las acciones de la cola aplicadas encima
   (estado de la PQRS tal como la dejaría la acción, marcadas "pendiente").
2. En paralelo intenta leer Firestore; al responder reemplaza la caché
   (`replaceAll`, como `MotelDao`) y notifica con `notifyListeners`.
3. Si Firestore falla y hay caché, se muestra la caché con un aviso; si no hay
   caché, estado de error con "Reintentar".

### Escritura sin conexión y relación con el `WriteBatch`

- Cada acción (radicar, comentar, avanzar, resolver, rechazar, cerrar) se
  guarda **primero** en `pqrs_outbox` con ids generados en el cliente
  (`pqrsId`, `traceId`, ids de foto). Una acción = un `WriteBatch`: documento
  `pqrs` (si cambia), entrada `traces` y sus `photos` en un solo lote atómico,
  tal como ya se decidió.
- Al sincronizar se reconstruye el lote desde la fila y sus fotos. Como los ids
  son fijos, reintentar es **idempotente**: no duplica aunque el primer intento
  haya llegado y la respuesta se perdiera.
- Se envían **en orden de creación por PQRS**; si una falla con `failed`, las
  posteriores de esa misma PQRS esperan (dependen de su estado).
- `createdAt`/`updatedAt` usan la hora del servidor (`request.time` en las
  reglas), por lo que la fecha mostrada puede cambiar un poco al sincronizar; la
  UI muestra mientras tanto la hora local de la acción.

### Reglas de estado sin conexión

- Sin red la app valida con la **copia local**: oculta botones y rechaza
  transiciones evidentemente inválidas (por ejemplo cerrar una PQRS que la
  caché dice que no está `resolved`), solo como comodidad.
- La validación definitiva ocurre **al sincronizar**, en `firestore.rules`. Si
  la copia local estaba desactualizada y la regla rechaza, la acción pasa a
  `failed` y la UI muestra por qué (ver conflicto abajo).

### Conflictos (mínimo)

- **Firestore manda.** No hay fusión de campos. Si al leer llega una versión
  más nueva, la caché la reemplaza.
- Conflicto típico: el cliente comenta sin red mientras el propietario marca
  `rejected`. Al sincronizar la regla rechaza el comentario (PQRS final) →
  `failed` con el mensaje "La solicitud cambió de estado mientras estabas sin
  conexión". El texto del usuario no se pierde (queda en la fila `failed`);
  puede copiarlo o descartarlo.
- Otro caso: el cliente cierra sin red pero el propietario la reabrió →
  la regla rechaza → `failed`.

### Qué NO se hará (demasiado complejo para el semestre)

- Sincronización en segundo plano con la app cerrada (workmanager, etc.).
- Fusión automática o reintento inteligente tras un conflicto.
- Caché local de fotos ya enviadas.
- Cifrado de la base local (datos personales mínimos: nombre del cliente).
- Detección de conectividad con paquete nuevo.
- Uso de la persistencia offline integrada del SDK de Firestore como
  mecanismo principal. Se descarta porque una escritura rechazada por reglas
  se pierde sin que la UI pueda mostrar su estado, y porque el equipo pidió
  Floor para esta etapa; el SDK puede mantener su caché propia sin que la app
  dependa de ella (D13).

### Migración de base (no ejecutada)

`AppDatabase` pasa de la versión **17 a 18** con `migration17To18`, que solo
ejecuta `CREATE TABLE IF NOT EXISTS` para las 4 tablas de la cola y la caché
(`pqrs_cache`, `pqrs_trace_cache`, `pqrs_outbox`, `pqrs_outbox_photo`) y para
las 2 de caché de los maestros de Supabase (`allowed_image_formats` y `pqrs_types`),
sin tocar las existentes, y se agrega al listado de migraciones. Requiere regenerar
`app_database.g.dart` con `build_runner`. **Aviso:** `docs/decisions_log.md`
(2026-11-07) dice que la próxima migración usa la 16; es una cifra vieja, el
código ya está en 17. Antes de crear la 18 hay que confirmar con el equipo que
nadie más la tomó (D12).

### Escenarios (Gherkin)

  Scenario: Radicar sin conexión
    Given un cliente autenticado sin conexión a internet
    When completa el formulario válido y presiona "Enviar"
    Then la solicitud se guarda en la cola local con estado "pending_sync"
    And aparece en "Mis solicitudes" marcada "Pendiente de envío"
    And ve un aviso de que se enviará al recuperar la conexión

  Scenario: Reconexión y sincronización
    Given una solicitud en "pending_sync"
    When la app recupera la conexión y se reintenta el envío
    Then Firestore recibe el lote (PQRS, entrada y fotos) y lo confirma
    And la marca "Pendiente de envío" desaparece
    And la solicitud no queda duplicada aunque el envío se repita

  Scenario: Comentario sin conexión
    Given una PQRS propia en "in_progress" y sin red
    When el cliente envía un comentario
    Then el comentario aparece en el timeline marcado "Pendiente de envío"
    And el estado de la PQRS no cambia

  Scenario: Fallo de sincronización por rechazo del servidor
    Given una acción en "pending_sync" que las reglas de Firestore no permiten
    When se intenta enviar
    Then la acción pasa a "failed" y la UI muestra el motivo
    And el usuario puede elegir "Reintentar" o "Descartar"
    And no se envía ninguna acción posterior de esa misma PQRS hasta resolverlo

  Scenario: Fallo de red no cuenta como fallo de sincronización
    Given una acción en "pending_sync"
    When el envío falla por falta de red o tiempo de espera
    Then sigue en "pending_sync" y se reintenta después

  Scenario: Lectura sin red con caché
    Given una caché con PQRS leídas antes
    When el usuario abre su lista sin conexión
    Then ve las solicitudes guardadas con un aviso "Datos guardados, sin conexión"

  Scenario: Lectura sin red y sin caché
    Given una instalación sin caché de PQRS y sin conexión
    When el usuario abre su lista
    Then ve un mensaje de error claro con la opción "Reintentar"

  Scenario: Conflicto con cambio de estado
    Given un cliente sin conexión que escribió un comentario sobre una PQRS "in_progress"
    And entretanto el propietario la rechazó ("rejected")
    When el cliente recupera la conexión
    Then Firestore rechaza el comentario porque la PQRS es final
    And la acción queda en "failed" con el mensaje "La solicitud cambió de estado mientras estabas sin conexión"
    And la caché se actualiza al estado real "rejected"

  Scenario: Firestore manda sobre la copia local
    Given una caché con la PQRS en "resolved"
    When Firestore devuelve la misma PQRS en "closed"
    Then la lista muestra "closed" y reemplaza la copia local

## Validación de imágenes con configuración en Supabase

**Decisión tomada (D10):** Supabase guarda **solo la
configuración y los catálogos** (qué formatos de imagen se aceptan, con qué
límites y qué tipos de PQRS existen). Los
datos de la PQRS y las fotos siguen en Firebase (Firestore), como ya se decidió
en D1. Esa configuración es de **solo lectura desde la app**: se edita en el
panel de Supabase y la app la consulta antes de elegir y enviar fotos. Es el
mismo uso de "maestro" que ya hacen los indicativos telefónicos y las
categorías de reservas (`docs/decisions_log.md`, 2026-10-20 y 2026-11-07).

### Cómo se consulta Supabase hoy (y qué se reutiliza)

- `PhoneCountryCodeRepository`
  (`lib/database/repository/phone_country_code/supabase_phone_country_code_repository.dart`)
  hace `GET {baseUrl}/rest/v1/<tabla>?select=...&active=eq.true` con el
  paquete `http` ya presente en el proyecto, cabecera `apikey`, decodifica UTF-8,
  reemplaza la caché Floor (`deleteAll` + `insert`) y, si falla, devuelve la
  caché o lanza una excepción propia.
- Configuración: `SupabaseConfig` (`lib/service/supabase/supabase_config.dart`)
  con `--dart-define` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
- Migraciones de maestros en `supabase/migrations/` con RLS de solo lectura
  para `anon` y `authenticated` (ejemplo: `reservation_categories`).
- Se reutiliza todo esto **sin dependencias nuevas**.

**Cliente de Supabase:** la alternativa sería el paquete
`supabase_flutter`, pero el repositorio consulta Supabase por REST con `http` y
`supabase_flutter` sería una dependencia nueva que nadie acordó (CLAUDE.md:
no agregar dependencias por cuenta propia). Se documenta con `http`; el cambio
queda como D15.

**Diferencia a tener en cuenta:** el repositorio de indicativos es *cache
first* (si hay caché no consulta, salvo `forceRefresh`). Para esta
configuración eso es riesgoso: un formato desactivado (`is_active = false`) seguiría
aceptándose. Por eso el nuevo repositorio es **network first con caché de
respaldo**: consulta Supabase al abrir el selector de fotos y usa la caché solo
si falla.

### Tablas en Supabase

Nombres técnicos en inglés. El SQL completo e idempotente (crea las tablas si
no existen o las lleva a su forma final si ya existen) está en
`supabase/migrations/202611100001_create_pqrs_config.sql`; el equipo lo aplica
en Supabase. Los fragmentos de abajo son explicativos.

```sql
-- Mantiene updated_at en cada UPDATE.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Formatos de imagen permitidos para adjuntos de PQRS.
create table if not exists public.allowed_image_formats (
  id bigint generated by default as identity primary key,
  mime_type text not null unique check (length(trim(mime_type)) > 0),
  extensions text[] not null check (cardinality(extensions) > 0),
  -- Cada firma: {"offset": <int>, "hex": "<bytes en hexadecimal>"}.
  -- El archivo debe cumplir TODAS las signatures de su formato.
  signatures jsonb not null check (jsonb_typeof(signatures) = 'array'),
  max_size_bytes integer not null default 921600
    check (max_size_bytes between 1 and 921600),
  is_active boolean not null default true,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Configuración general de PQRS: una sola fila (id = 1).
create table if not exists public.pqrs_settings (
  id smallint primary key default 1 check (id = 1),
  max_photos smallint not null default 3 check (max_photos between 1 and 3),
  image_quality smallint not null default 60
    check (image_quality between 1 and 100),
  max_width_px integer not null default 1280
    check (max_width_px between 100 and 4096),
  max_height_px integer not null default 1280
    check (max_height_px between 100 and 4096),
  updated_at timestamptz not null default now()
);

drop trigger if exists set_allowed_image_formats_updated_at
  on public.allowed_image_formats;
create trigger set_allowed_image_formats_updated_at
  before update on public.allowed_image_formats
  for each row execute function public.set_updated_at();

drop trigger if exists set_pqrs_settings_updated_at on public.pqrs_settings;
create trigger set_pqrs_settings_updated_at
  before update on public.pqrs_settings
  for each row execute function public.set_updated_at();

insert into public.allowed_image_formats
  (mime_type, extensions, signatures, max_size_bytes, is_active, description)
values
  ('image/jpeg', array['jpg','jpeg'],
    '[{"offset":0,"hex":"FFD8FF"}]', 921600, true, 'JPEG'),
  ('image/png', array['png'],
    '[{"offset":0,"hex":"89504E470D0A1A0A"}]', 921600, true, 'PNG'),
  ('image/webp', array['webp'],
    '[{"offset":0,"hex":"52494646"},{"offset":8,"hex":"57454250"}]',
    921600, true, 'WebP (RIFF en offset 0 y WEBP en offset 8)')
on conflict (mime_type) do nothing;

insert into public.pqrs_settings (id) values (1) on conflict (id) do nothing;
```

Notas:

- `921600` bytes = 900 KB: el tope por foto ya decidido en D1 (la foto vive en
  un documento de Firestore de máximo 1 MiB). El `check` impide que el panel
  configure un tamaño mayor, y `max_photos` no puede pasar de 3 por lo mismo.
- WebP lleva dos signatures (`RIFF` en `offset` 0 y `WEBP` en `offset` 8), por
  eso son una lista y deben cumplirse todas.
- `extensions` es un arreglo porque JPEG tiene `jpg` y `jpeg`.

### RLS de solo lectura (configuración del lado de Supabase)

"Solo lectura desde la app" **no se logra con código Flutter**: lo impone
Supabase. El equipo lo aplica en su proyecto con el archivo
`supabase/migrations/202611100001_create_pqrs_config.sql`; el fragmento de abajo
es explicativo. No hay políticas de escritura, así que `anon` y
`authenticated` no pueden insertar, modificar ni borrar:

```sql
alter table public.allowed_image_formats enable row level security;
alter table public.pqrs_settings enable row level security;

revoke all on table public.allowed_image_formats from anon, authenticated;
revoke all on table public.pqrs_settings from anon, authenticated;
grant select on table public.allowed_image_formats to anon, authenticated;
grant select on table public.pqrs_settings to anon, authenticated;

-- Solo se exponen los formatos activos.
create policy "Public can read active image formats"
  on public.allowed_image_formats
  for select to anon, authenticated
  using (is_active = true);

create policy "Public can read pqrs settings"
  on public.pqrs_settings
  for select to anon, authenticated
  using (true);
```

Los cambios se hacen desde el panel de Supabase o con la llave `service_role`,
que ignora RLS. La llave que usa la app es pública por diseño; por eso nunca
debe tener permisos de escritura sobre estas tablas, y la `service_role` no
debe incluirse en la app ni en el repositorio.

**Consecuencia de filtrar por `is_active = true` en RLS:** un formato
desactivado **no llega** en la respuesta; la app no distingue "desactivado" de
"no existe". Por eso la consulta no necesita filtro propio, y la caché local se
**reemplaza por la respuesta completa** (no se fusiona): así un formato
desactivado desaparece de la caché en la siguiente consulta exitosa.

### Caché local y valores por defecto

Se elige lo más simple y coherente con el repositorio:

| Dato | Dónde se cachea | Por qué |
|---|---|---|
| `allowed_image_formats` (lista) | Tabla Floor `allowed_image_formats` (`id`, `mimeType`, `extensions` y `signatures` como JSON en TEXT, `maxSizeBytes`, `isActive`), con `replaceAll` (borra todo e inserta la respuesta completa) tras cada consulta exitosa | Es un maestro en forma de lista, igual que `phone_country_codes` y `motels`; las listas como JSON ya se usan en `MotelEntity`. |
| `pqrs_settings` (una fila) | `shared_preferences` vía `LocalPreferencesService`, como un solo JSON bajo una clave `pqrsSettings` (`max_photos`, `image_quality`, `max_width_px`, `max_height_px`) | Una sola fila no justifica una tabla ni una migración propia; `shared_preferences` ya está decidido para datos locales sueltos. |

**Valor por defecto seguro** (si no hay red **ni** caché), constante única en
el validador, no repartida por las vistas: JPEG (`FFD8FF`), PNG
(`89504E470D0A1A0A`) y WebP (`RIFF` en offset 0 + `WEBP` en offset 8),
921600 bytes cada uno, `max_photos = 3`, `image_quality = 60`,
`max_width_px = max_height_px = 1280`. Coincide con D1 y con las reglas de
Firestore.

Cadena al validar: **1)** Supabase **2)** caché **3)** valor por defecto. Un
formato con `is_active = false` nunca se acepta, venga de donde venga. Si
falla el formato pero no la configuración (o al revés), cada parte usa su
propia cadena.

### Qué valida la app, por foto

Se aplica a la foto ya comprimida (con `image_quality`, `max_width_px` y
`max_height_px` de la configuración), antes de guardarla en la cola o enviarla:

1. **Tipo.** Se toma el MIME que informa el selector; si es `null`, se deduce de
   la extensión del nombre del archivo (**fallback**, contra `extensions`).
   El formato debe existir en `allowed_image_formats` con `is_active = true`.
   Si no hay MIME ni extensión reconocible, se rechaza.
2. **Firmas (magic bytes).** Los primeros bytes del archivo deben coincidir con
   **todas** las `signatures` (`offset` + `hex`) del formato. Detecta archivos
   renombrados (por ejemplo un `.exe` o un GIF llamado `foto.jpg`).
3. **Tamaño.** El tamaño comprimido debe ser menor o igual que `max_size_bytes`
   del formato.
4. **Cantidad.** La cantidad de fotos de la entrada debe ser menor o igual que
   `max_photos`.

Las comprobaciones 1 a 4 viven en una **función pura y testeable**
(`PqrsImageValidator.validate(bytes, mimeType, fileName, formats, settings,
currentCount)` que devuelve el error o `ok`), sin acceso a red, a la base ni a
Flutter. Así se prueba con bytes de ejemplo sin dispositivo. La vista solo
muestra el mensaje; el controlador la invoca (la vista no valida ni consulta).

### Dónde se valida (y por qué dos veces)

| Capa | Qué valida | Notas |
|---|---|---|
| Cliente (app) | Los 4 pasos anteriores con la configuración de Supabase/caché/por defecto | Da mensajes claros. **No es autorización.** |
| `firestore.rules` | Lista fija: `mimeType in ['image/jpeg','image/png','image/webp']`, `bytes.size() <= 921600`, máximo 3 fotos por entrada (ids `<traceId>_1..3`) | **Es la validación real del servidor.** Las reglas **no pueden leer Supabase**, por eso tipo, tamaño y cantidad se escriben a mano. No pueden revisar firmas ni calidad/dimensiones: esas solo las valida el cliente. |

Consecuencia (coherente con D14): **cambiar un valor en Supabase no cambia las
reglas.** Bajar el tamaño máximo, desactivar un formato (`is_active = false`) o
bajar `max_photos` funciona de inmediato (el cliente es más estricto).
**Agregar** un formato (p. ej. HEIC) o **subir** un límite exige también editar
y desplegar `firestore.rules`; el `check` de SQL (900 KB y 3 fotos) existe para
que no se pueda configurar algo que las reglas rechazarían por tamaño o
cantidad.

### Catálogo de tipos de PQRS (`pqrs_types`)

Supabase guarda también el catálogo de tipos de solicitud: qué tipos existen,
cómo se muestran y cuánto tarda la respuesta. Es de **solo lectura desde la
app** (RLS para `anon` y `authenticated`, solo filas con `is_active = true`) y
se edita desde el panel de Supabase o con `service_role`.

| Columna | Uso |
|---|---|
| `code` | Identificador estable (`peticion`, `queja`, `reclamo`, `sugerencia`). **Es el único valor que se guarda en Firestore**, en el campo `type` de la PQRS. |
| `name` | Nombre visible en la app. Nunca se guarda en Firestore. |
| `description` | Texto de ayuda para el cliente al elegir el tipo. |
| `response_days` | Días hábiles de respuesta (15 por defecto); sirve para mostrar la fecha estimada. |
| `allows_photos` | Si es `false`, el formulario no muestra el selector de fotos para ese tipo. |
| `sort_order` | Orden en la lista. |
| `is_active`, `created_at`, `updated_at` | Vigencia y auditoría; `updated_at` lo mantiene el trigger `set_updated_at()` ya definido. |

El SQL completo está en `supabase/migrations/202611100001_create_pqrs_config.sql`
(lo aplica el equipo en Supabase); el fragmento de abajo es explicativo y usa la
función `set_updated_at()` definida arriba:

```sql
create table if not exists public.pqrs_types (
  id bigint generated by default as identity primary key,
  code text not null unique
    check (code in ('peticion', 'queja', 'reclamo', 'sugerencia')),
  name text not null check (length(trim(name)) > 0),
  description text not null check (length(trim(description)) > 0),
  response_days smallint not null default 15
    check (response_days between 1 and 90),
  allows_photos boolean not null default true,
  sort_order smallint not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists set_pqrs_types_updated_at on public.pqrs_types;
create trigger set_pqrs_types_updated_at
  before update on public.pqrs_types
  for each row execute function public.set_updated_at();

alter table public.pqrs_types enable row level security;
revoke all on table public.pqrs_types from anon, authenticated;
grant select on table public.pqrs_types to anon, authenticated;

create policy "Public can read active pqrs types"
  on public.pqrs_types
  for select to anon, authenticated
  using (is_active = true);

insert into public.pqrs_types
  (code, name, description, response_days, allows_photos, sort_order)
values
  ('peticion', 'Petición',
    'Solicita información o un servicio del motel.', 15, true, 1),
  ('queja', 'Queja',
    'Expresa tu inconformidad con la atención o el servicio recibido.', 15, true, 2),
  ('reclamo', 'Reclamo',
    'Reclama por un cobro, un servicio no prestado o un derecho incumplido.', 15, true, 3),
  ('sugerencia', 'Sugerencia',
    'Propón una mejora para el motel o la plataforma.', 15, true, 4)
on conflict (code) do nothing;
```

El `check` sobre `code` evita que el panel cree un código que las reglas de
Firestore rechazarían; ampliarlo exige el cambio coordinado de D17.

**Uso en la app:** consultar los tipos activos ordenados por `sort_order`,
mostrar `name` y `description`, guardar solo `code` en `type` y respetar
`allows_photos` al armar el formulario.

**Caché y valores por defecto** (mismo criterio que `allowed_image_formats`):
- *Network first*; si falla, caché; si no hay caché, valor por defecto.
- Tabla Floor `pqrs_types` (`id`, `code`, `name`, `description`,
  `responseDays`, `allowsPhotos`, `sortOrder`, `isActive`) reemplazada por la
  **respuesta completa** (`replaceAll`), así un tipo desactivado desaparece.
- Por defecto, los cuatro tipos del enum con las etiquetas actuales
  (`Petición`, `Queja`, `Reclamo`, `Sugerencia`), `response_days = 15`,
  `allows_photos = true` y los textos de ayuda del `insert` anterior.
- Impacto en la migración (D12): `migration17To18` crea **6 tablas** en vez
  de 5 (se suma `pqrs_types`); sigue siendo solo `CREATE TABLE IF NOT EXISTS`.

**Relación con el enum `PqrsType`** (`lib/models/pqrs/pqrs.dart`): el `code`
mapea al enum por nombre (`peticion`, `queja`, `reclamo`, `sugerencia`). Un
`code` desconocido que llegue de Supabase **se ignora** (no se muestra ni se
puede elegir), porque la app no sabría guardarlo ni las reglas lo admitirían.
Las etiquetas de `lib/widgets/pqrs/pqrs_presentation.dart` (hoy fijas, con el
icono de cada tipo) quedan como valor por defecto y como respaldo si falta un
`name`; los iconos siguen resolviéndose en la capa de presentación, no vienen
de Supabase.

**Cola offline:** una PQRS en `pqrs_outbox` guarda solo el `code`. La
validación de `allows_photos` ocurre **al radicar**, con la configuración
vigente en ese momento. Si después `allows_photos` pasa a `false`, lo ya
encolado se envía tal cual: las reglas de Firestore no conocen `allows_photos`
y lo aceptan si cumple el resto de validaciones. Lo mismo vale si el tipo se
desactiva: lo encolado con ese `code` se envía mientras las reglas lo admitan.

**Fecha estimada de respuesta:** se calcula en la app como fecha de creación
más `response_days` días hábiles (lunes a viernes, **sin considerar festivos**;
es una aproximación). Es solo informativa: no cambia estados, no se guarda en
Firestore y no genera alertas.

**Reglas de Firestore:** no pueden leer Supabase, así que la lista de códigos
válidos también está escrita en ellas: `type in ['peticion','queja','reclamo','sugerencia']`.
Si se agrega o cambia un `code` en Supabase hay que actualizar y desplegar las
reglas (D14, D17).

### Escenarios de tipos (Gherkin)

  Scenario: Lista de tipos ordenada
    Given pqrs_types con los cuatro tipos activos y sort_order 1 a 4
    When el cliente abre el formulario de nueva solicitud
    Then ve Petición, Queja, Reclamo y Sugerencia en ese orden
    And cada uno muestra su description como texto de ayuda

  Scenario: Tipo sin fotos
    Given un tipo con allows_photos = false
    When el cliente lo selecciona
    Then el formulario no muestra el selector de fotos
    And las fotos ya elegidas para otro tipo se descartan

  Scenario: Tipo inactivo
    Given el tipo "reclamo" con is_active = false en Supabase
    When la app consulta con éxito y reemplaza la caché con la respuesta completa
    Then "Reclamo" no aparece en la lista ni en la caché

  Scenario: Supabase caído con caché
    Given una caché local de pqrs_types
    When Supabase no responde al abrir el formulario
    Then se muestran los tipos de la caché

  Scenario: Sin Supabase y sin caché
    Given Supabase inaccesible y ninguna caché
    When el cliente abre el formulario
    Then ve los cuatro tipos por defecto con 15 días hábiles y fotos permitidas

  Scenario: Solo se guarda el code
    Given un cliente que elige el tipo "Queja"
    When radica la solicitud
    Then el documento de Firestore guarda type = "queja"
    And no guarda el nombre visible ni la descripción del tipo

  Scenario: Code no permitido por las reglas
    Given un code "felicitacion" agregado en Supabase que las reglas no incluyen
    When el cliente radica una solicitud con ese tipo
    Then Firestore rechaza el documento y la acción queda "failed" con el motivo

  Scenario: Code desconocido para la app
    Given Supabase devuelve un code que no existe en el enum PqrsType
    When la app arma la lista de tipos
    Then ese tipo se ignora y los demás se muestran normalmente

  Scenario: Fecha estimada de respuesta
    Given un tipo con response_days = 15 y una solicitud creada un lunes
    When el cliente abre el detalle
    Then ve una fecha estimada 15 días hábiles después (lunes a viernes, sin festivos)
    And esa fecha es solo informativa y no cambia el estado

  Scenario: Cambio de allows_photos con solicitud en cola
    Given una solicitud ya encolada con fotos para un tipo
    When allows_photos pasa a false antes de sincronizar
    Then se envía tal cual si las reglas la aceptan
    And las nuevas solicitudes de ese tipo ya no muestran el selector de fotos

### Escenarios de imágenes (Gherkin)

  Scenario: Formato permitido
    Given la configuración de Supabase con "image/jpeg" (is_active = true) y firma "FFD8FF"
    When el cliente adjunta una foto JPEG de 400 KB
    Then la foto se acepta y se incluye en el lote

  Scenario: Formato no permitido
    Given una foto GIF
    When el cliente intenta adjuntarla
    Then ve "Formato de imagen no permitido" con los formatos aceptados
    And la foto no se agrega

  Scenario: Archivo renombrado con firma que no coincide
    Given un archivo GIF renombrado como "foto.jpg" con tipo informado "image/jpeg"
    When el cliente intenta adjuntarlo
    Then sus primeros bytes no coinciden con la firma de JPEG
    And ve "El archivo no es una imagen válida" y no se agrega

  Scenario: Tipo nulo con extensión válida
    Given una foto "camara.png" cuyo mimeType informado es null y con firma de PNG correcta
    When el cliente la adjunta
    Then se deduce "image/png" de la extensión y se acepta

  Scenario: Tipo nulo con extensión desconocida
    Given un archivo sin mimeType y con extensión ".xyz"
    When el cliente intenta adjuntarlo
    Then se rechaza como formato no permitido

  Scenario: WebP exige las dos firmas
    Given un archivo con "RIFF" en la posición 0 pero sin "WEBP" en la posición 8
    When el cliente intenta adjuntarlo como WebP
    Then se rechaza por firma inválida

  Scenario: Formato desactivado en Supabase
    Given el formato "image/png" cambiado a is_active = false en Supabase
    And que RLS solo devuelve los formatos con is_active = true
    When la app consulta con éxito y reemplaza la caché con la respuesta completa
    Then "image/png" ya no está en la caché ni en la lista de formatos aceptados
    And al adjuntar un PNG ve "Formato de imagen no permitido"
    And los demás formatos activos siguen aceptándose

  Scenario: Foto que supera el tamaño del formato
    Given un formato con is_active = true y max_size_bytes = 512000
    When el cliente adjunta una foto comprimida de 700 KB
    Then ve "La imagen supera el tamaño máximo (500 KB)" y no se agrega

  Scenario: Cambio de max_photos en Supabase
    Given pqrs_settings con max_photos = 2 (antes 3)
    When el cliente abre el selector y ya adjuntó 2 fotos
    Then no puede agregar una tercera y ve "Máximo 2 fotos"

  Scenario: Cambio de calidad y dimensiones en Supabase
    Given pqrs_settings con image_quality = 40 y max_width_px = 1000
    When el cliente elige una foto
    Then la app la comprime con calidad 40 y ancho máximo 1000 antes de validarla

  Scenario: Supabase caído con caché disponible
    Given una caché local con la configuración de una consulta anterior
    When Supabase no responde al abrir el selector de fotos
    Then se valida con la caché y el adjuntar no se bloquea

  Scenario: Sin Supabase y sin caché
    Given Supabase inaccesible y ninguna caché
    When el cliente adjunta una foto JPEG válida
    Then se valida con el valor por defecto (JPEG, PNG, WebP; 900 KB; 3 fotos; calidad 60; 1280 px) y se acepta

  Scenario: Formato nuevo que las reglas no conocen
    Given un formato agregado en Supabase que no está en la lista fija de las reglas
    When el cliente lo adjunta y la app lo acepta
    Then Firestore rechaza el lote al sincronizar y la acción queda "failed" con el motivo
    And el equipo debe actualizar y desplegar las reglas para admitirlo

  Scenario: Cuarta foto con configuración por defecto
    Given una entrada con 3 fotos ya adjuntas
    When intenta agregar otra
    Then ve "Máximo 3 fotos" y no se agrega

## Decisiones del módulo

El responsable del módulo aprobó las decisiones **D1 a D18**. Cada fila
describe la decisión tomada. D10 se explica con detalle más abajo como sustento.

| Id | Estado | Tema | Decisión tomada |
|---|---|---|---|
| D1 | Aprobada | Almacenamiento de imágenes | Bytes en Firestore, subcolección `pqrs/{pqrsId}/photos`, registrada en `docs/decisions_log.md` (2026-11-10). `image_picker` es la única dependencia nueva acordada. Ver "Almacenamiento de imágenes". |
| D2 | Aprobada | Comentario del cliente en `resolved` | Reabre la solicitud a `in_progress`, limpia `resolvedAt` y deja el cambio en el timeline. |
| D3 | Aprobada | Cliente que nunca confirma | **Cierre por vencimiento** a cargo del propietario: pasados 7 días corridos desde `resolvedAt`, el propietario puede cerrar con "Cerrar por falta de respuesta". Las reglas de Firestore lo exigen; no usa Cloud Functions, plan Blaze ni procesos en segundo plano. Ver "Cierre por vencimiento del plazo de confirmación". |
| D4 | Aprobada | Quién puede radicar sobre un motel | Cualquier cliente activo, sobre cualquier motel. No se depende de reservas. |
| D5 | Aprobada | "Tasa de cerradas por cliente" | `closed` con `closedBy = client` / (`resolved` + `closed`). El denominador es el aprobado; el numerador cuenta solo los cierres confirmados por el cliente (los cierres por vencimiento quedan en el denominador pero no en el numerador). Ver "Cierre por vencimiento". |
| D6 | Aprobada | Trazabilidad | Subcolección `traces`. |
| D7 | Aprobada | Archivo de la vista de PQRS | El archivo es `lib/views/pqrs/pqrs_page.dart` (`snake_case`) y `lib/routes/routes.dart` lo importa con ese nombre. El selector de perfil de prueba (`PqrsProfilePicker`) se quita cuando haya sesión. |
| D8 | Aprobada | Datos del cliente visibles al propietario | Solo nombre, sin correo ni teléfono. |
| D9 | Aprobada | `systemAdmin` como autor de trazas | Solo lectura en esta especificación. |
| D10 | Aprobada | Tablas de configuración y catálogos en Supabase | Las tres tablas `allowed_image_formats`, `pqrs_settings` y `pqrs_types`, de solo lectura para la app (RLS). SQL completo e idempotente en `supabase/migrations/202611100001_create_pqrs_config.sql`, que el equipo aplica en Supabase. Ver "Decisión D10 en detalle". |
| D11 | Aprobada | Cola de escritura offline | `pqrs_outbox` en SQLite con `pending_sync`/`synced`/`failed`; Firestore manda. |
| D12 | Aprobada | Migración de `AppDatabase` | `migration17To18` solo con `CREATE TABLE IF NOT EXISTS`, confirmando antes que nadie más use la 18. Se corrige la cifra "la próxima es la 16" del registro. Crea las 6 tablas locales: 4 de cola y caché de PQRS (`pqrs_cache`, `pqrs_trace_cache`, `pqrs_outbox`, `pqrs_outbox_photo`) y 2 de caché de maestros (`allowed_image_formats`, `pqrs_types`). |
| D13 | Aprobada | Persistencia offline integrada del SDK de Firestore | No depender de ella; la cola de la app es la fuente de estado. |
| D14 | Aprobada | Valores que las reglas no conocen | Tipo de imagen, tamaño, cantidad, lista de `code` y plazo de 7 días van escritos en las reglas (no pueden leer Supabase). Agregar un formato o un `code`, o subir un límite, exige editar y desplegar `firestore.rules`. Bajar un límite o desactivar un formato o tipo sí funciona de inmediato. |
| D15 | Aprobada | Cliente de Supabase | Se mantiene `http` (REST, ya en el repo); no se agrega `supabase_flutter`. |
| D16 | Aprobada | Dónde cachear `pqrs_settings` | `shared_preferences` (una sola fila, sin migración). |
| D17 | Aprobada | Sincronía de los `code` de `pqrs_types` con reglas y enum | Los `code` son estables: no se editan, solo se desactivan; agregar uno es un cambio coordinado (SQL en Supabase + enum `PqrsType` + `firestore.rules`). |
| D18 | Aprobada | Plazo de respuesta (`response_days`) | Solo informativo, calculado en la app en días hábiles (lunes a viernes, sin festivos); no se guarda ni cambia estados. |

### Decisión D10 en detalle

**Estado: aprobada.** El responsable del módulo aprobó las tres tablas de
Supabase. Esta sección conserva la explicación como sustento de la decisión. El
SQL completo e idempotente (crea las tablas si no existen o las lleva a su
forma final si ya existen) está en
`supabase/migrations/202611100001_create_pqrs_config.sql`; el equipo lo aplica
en Supabase. Las secciones "Validación de imágenes con configuración en
Supabase" y "Catálogo de tipos de PQRS" describen su uso en la app.

**(a) El problema.** Si los formatos de imagen, los límites de tamaño y de
cantidad, la calidad de compresión y los tipos de PQRS (con su texto de ayuda y
plazo) quedan escritos solo en el código y en las reglas, cambiar uno obliga a
**recompilar y redistribuir la app**.

**(b) La decisión.** Tres tablas en Supabase, de configuración y solo lectura
para la app:

| Tabla | Qué contiene |
|---|---|
| `allowed_image_formats` | Formatos permitidos: `mime_type`, `extensions`, `signatures` (`offset` y `hex` de los magic bytes), `max_size_bytes`, `is_active`. |
| `pqrs_settings` | Una sola fila: `max_photos`, `image_quality`, `max_width_px`, `max_height_px`. |
| `pqrs_types` | Tipos de PQRS: `code`, `name`, `description`, `response_days`, `allows_photos`, `sort_order`, `is_active`. |

Las edita el equipo desde el panel de Supabase o con la llave `service_role`. La
app solo lee: lo impone RLS (`select` para `anon` y `authenticated`, filas con
`is_active = true` en formatos y tipos, sin políticas de escritura).

**(c) Cómo funciona.** Ejemplo: Ana, una cliente, abre "Nueva solicitud".

1. La app consulta Supabase (`pqrs_types`, `allowed_image_formats`,
   `pqrs_settings`) y guarda la respuesta completa en la caché local (Floor
   para tipos y formatos, `shared_preferences` para la configuración).
2. Ana ve los tipos por `sort_order` con su texto de ayuda y elige "Queja".
3. Si el tipo tiene `allows_photos = true`, ve el selector de fotos y elige
   "camara.png".
4. La app la comprime con `image_quality`, `max_width_px` y `max_height_px` y
   valida: formato activo, primeros bytes iguales a la firma de PNG, tamaño
   menor o igual que `max_size_bytes` y cantidad menor o igual que `max_photos`.
5. Ana presiona "Enviar": un solo lote en Firestore con la PQRS
   (`type = "queja"`, solo el `code`), su primera entrada de trazabilidad y la
   foto.
6. Las reglas de Firestore validan de nuevo tipo, tamaño y cantidad con su lista
   fija y aceptan el lote.

Si algo falla:
- **Supabase caído con caché:** usa la última caché.
- **Supabase caído sin caché:** usa los valores por defecto (los cuatro tipos,
  JPEG/PNG/WebP, 900 KB, 3 fotos, calidad 60, 1280 px); el formulario no se
  bloquea.
- **Se desactiva un formato en Supabase:** RLS deja de devolverlo, la caché se
  reemplaza con la respuesta completa y la app rechaza ese formato sin publicar
  una versión nueva.

**(d) Qué NO puede hacer.** Las reglas de Firestore **no pueden leer
Supabase**: la lista de `code`, los tipos de imagen, el tamaño máximo, la
cantidad máxima y el plazo de 7 días del cierre por vencimiento están
**duplicados a mano** en `firestore.rules` (D14). Agregar un `code` o un formato
nuevo, o subir un límite, exige además editar y desplegar las reglas y, para un
`code`, actualizar el enum `PqrsType`. El maestro sirve sobre todo para
**restringir** (desactivar, bajar límites) y para ajustar textos, orden, plazos
y calidad sin publicar la app.

**(e) Costo para el equipo.** Tres tablas en Supabase con RLS; un repositorio
REST de configuración con `http`; dos tablas Floor de caché (formatos y tipos)
incluidas en la migración 17 a 18 junto con las cuatro de la cola y la caché de
PQRS (6 en total); una constante con los valores por defecto; y pruebas del
repositorio con HTTP simulado.

**(f) Alternativa descartada: lista fija en código y reglas.** Tenía menos
piezas y una sola fuente de verdad, pero cada cambio exigía recompilar y
redistribuir la app y no permitía ajustar textos ni plazos en caliente.

**(g) Riesgos y mitigaciones.**

| Riesgo | Mitigación |
|---|---|
| Supabase está en plan de prueba o gratuito y puede pausarse o caer | Caché local y valores por defecto: el formulario sigue funcionando sin Supabase. |
| Dos fuentes de verdad (Supabase y reglas) pueden desalinearse | Los `code` y los límites del `check` de SQL (900 KB, 3 fotos) coinciden con las reglas; se deja un comentario en ambos lados (D17). |
| Un cambio en Supabase se ve en la app solo al consultar | Consulta *network first* al abrir el formulario; la caché se reemplaza completa. |
| La llave pública quedara con permisos de escritura | RLS solo con `select`, sin políticas de escritura; revisar al aplicar el SQL. |

**(h) Contexto de la decisión.** Frente a la lista fija, la decisión cuesta más
piezas (3 tablas, 1 repositorio, 2 tablas Floor) a cambio de poder restringir
formatos y límites y ajustar textos, orden, plazos y calidad sin publicar la
app, y de aprovechar una tecnología ya decidida para datos maestros (Supabase
por REST). Las reglas de Firestore duplican de todos modos los valores
críticos.

## Notas para los agentes

- La única dependencia nueva acordada es `image_picker`. No agregar otras ni un
  gestor de estado: `ChangeNotifier` + `ListenableBuilder`.
- No reorganizar `lib/`; usar los directorios existentes.
- No modificar archivos de otras ramas (moteles, auth, reservas) sin avisar.
- El responsable de esta rama es dueño de todo el módulo PQRS, incluido
  `lib/models/pqrs/`. Al cambiarlo solo hay que verificar que la vista del
  administrador (`lib/views/pqrs/system_admin_view/`) siga compilando.
- Verificar con `flutter analyze lib/models/pqrs lib/controllers/pqrs lib/views/pqrs lib/widgets/pqrs`.
