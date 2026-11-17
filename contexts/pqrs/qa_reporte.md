# QA PQRS - verificación contra la especificación (2026-11-17)

Rama feature_josemanuelpavas. Resultado: `flutter test` 1280 en verde (1278 + 2 nuevas en
`test/controllers/pqrs/pqrs_type_catalog_test.dart`). `flutter analyze`: 104 info, 0 en archivos PQRS
(todos preexistentes en otras ramas: sql_connect, Notification.dart, add_payment_sheet, etc.).
Línea base del plan (1 info en `pqrs_store.dart:22`): el archivo ya fue borrado. Sin fallos nuevos.

## Criterios

| # | Estado | Evidencia |
|---|---|---|
| 1 | Cumple | `pqrs_controller_test::crea con la sesión como cliente, 3 fotos y estado pending`; `pqrs_firestore_document_test::new request stores pending...`; sin pqrsCurrent* en lib |
| 2 | Cumple | `pqrs_controller_test` (tabla de transiciones por estado); reglas 31/31 en `test_rules/pqrs.rules.test.mjs` (emulador, 193/193 en la suite) |
| 3 | Cumple | Reglas probadas en emulador (lectura ajena); controlador: `no puede comentar la solicitud de otro cliente` |
| 4 | Cumple | `closed y rejected no admiten nada`; reglas en emulador |
| 5 | Cumple | `rechazo con justificación corta es rechazado`; `pqrs_views_test::reject dialog requires at least 10 characters`; timeline renderiza la entrada |
| 6 | Cumple | views: `empty list...`, `empty inbox...`; controlador: `carga ... estado vacío`, `un fallo de conexión se expone y se puede reintentar` |
| 7 | Cumple | `pqrs_stats_test` (cero solicitudes, mixto, cierres por vencimiento fuera del numerador) |
| 8 | Cumple | pruebas de transiciones y PqrsStats presentes; analyze sin avisos PQRS |
| 9 | Cumple (revisión) | grep: radios/duraciones por tokens `AppRadius`; sin `0xFF` ni `Duration(` en `lib/widgets/pqrs`; ninguna vista PQRS importa cloud_firestore |
| 10 | Cumple + Manual | `synced_pqrs_repository_test` (cola, failed con motivo, retry/discard), `pqrs_views_test::failed action shows reason, retry and discard`. Manual: red real |
| 11 | Cumple + Manual | `la caché de la lista conserva la PQRS sin red`, `la lectura remota reemplaza la caché`. Aviso en vista: manual |
| 12 | Cumple | `pqrs_image_validator_test`, `pqrs_photo_controller_test`, repositorios de formatos y settings (defaults 900 KB/3/60/1280) |
| 13 | Cumple | reglas en emulador (tipo, tamaño, cantidad). Despliegue hecho el 2026-11-17 |
| 14 | Cumple | `cierra por vencimiento pasados 7 días`, `antes del plazo`/`justo en el límite es rechazado`, `marcar solucionada fija resolvedAt`, `reopening deletes resolvedAt`, views `resolved before/after the deadline`, `closed without closedBy counts as client` |
| 15 | Cumple | `supabase_pqrs_type_repository_test` (orden, inactivo, defaults, caché), `a type without photos hides the selector`, `sends only the type code`; reglas en emulador |
| 16 | Cumple | `pqrs_response_date_test` y nueva `pqrs_type_catalog_test` (no cambia estado). Pantalla del detalle/form: manual |
| 17 | Cumple | cola (`synced_pqrs_repository_test`, `pqrs_database_test`), validador, fecha estimada, vencimiento, code desconocido (`un code desconocido se ignora`), repos con HTTP simulado |

## Escenarios sin prueba automática (Manual)
Cámara/galería reales y permisos, compresión real, tiempos de red (timeout 10 s sin conexión), hora del
servidor para el plazo, 200 % de texto, reglas desplegadas contra la app real, "Mi desempeño" con datos reales.
Escenarios sin red de la sección sync se cubren con repositorio falso, no con red real.

## Checklist manual en dispositivo
1. Con red: radicar una PQRS (con 0, 1 y 3 fotos) y verificar en Firebase `status=pending`, `clientId` = uid.
2. Modo avión: radicar, comentar y ver la marca "Pendiente"; volver la red y comprobar que se sincroniza sin duplicar.
3. Modo avión: abrir la lista con datos previos (aviso "Datos guardados, sin conexión") y sin datos previos (error con Reintentar).
4. Dos cuentas cliente: A radica; B no ve la PQRS de A en su lista ni puede abrirla.
5. Propietario con dos moteles: la bandeja muestra PQRS de ambos; otro propietario no ve ninguna; filtro y "Mi desempeño".
6. Flujo: primer avance (pending a in_progress), resolver, el cliente ve la fecha límite y confirma y cierra; reabrir limpia el plazo.
7. Rechazo: menos de 10 caracteres bloqueado; con justificación visible en el timeline de ambos roles.
8. Plazo vencido: en la consola de Firebase editar `resolvedAt` de un documento de prueba a hace más de 7 días. El propietario ve "Cerrar por falta de respuesta" y cierra (`closedBy = owner_timeout`). Con `resolvedAt` reciente el botón no aparece.
9. Rechazo del servidor: en la consola cambiar el estado de una PQRS mientras otra acción está en cola sin red; al reconectar debe verse "No se pudo enviar" con motivo, Reintentar y Descartar.
10. Fotos: formato no permitido (GIF), foto mayor a 900 KB y cuarta foto rechazadas antes de guardar; `allows_photos=false` en Supabase oculta el selector.
11. Texto al 200 % y TalkBack/VoiceOver en lista, formulario y detalle.
