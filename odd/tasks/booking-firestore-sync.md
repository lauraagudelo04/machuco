# Booking: Firestore sync

Objective: share reservations between client, owner and admin through Cloud Firestore, keeping SQLite as the local cache.
Branch: `feature_daniel` · Delivery: `ask-on-risk` · Test runner: `flutter test` (Flutter via `mise which flutter`).

## Specs

- **S1** Firestore collection `reservations`; the booking repository saves each reservation locally (SQLite) and in Firestore. User's words: "Una colección `reservations` en Firestore, y el repositorio guardaría en ambos lados: SQLite como copia local y Firestore como fuente compartida." Offline or permission errors must not lose the local reservation (same contract as payments).
- **S2** Firestore security rules: "el cliente ve solo sus reservas, el propietario solo las de sus moteles y el admin todas."
- **S3** "Leer desde Firestore en las pantallas de propietario y admin, en lugar de la semilla local."
- **S4** (derived prerequisite, assumption) Booking controllers use the signed-in Firebase uid (`CurrentUser.uid`) as `guestId` / `ownerId` instead of `demoUserId` / `demoOwnerId`; without a session they keep the demo ids and work local-only, as today.
- **S5** Fix the origin of motel ownership (user chose option 1: "la 1, arregla el origen"): the owner's motel screens use the signed-in uid as `ownerId` (new motels get `owner_id = uid`, "my motels" filters by uid), demo id only without a session; the existing demo motels in Supabase are reassigned to a real owner account (user runs the SQL, Claude provides it).

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S4, S5 | inline | done | `2ea5f8c`; 3 tests; suite 465 green |
| T2 | S1 | inline | done | `d2f2513`; RED (missing file) → GREEN 3 tests |
| T3 | S2 | inline | done | `10e266f`; 31 emulator cases green; independent verifier: S2 met |
| T4 | S1, S3 | inline | done | `36ed12a`; RED → GREEN 12 tests; suite 480 green |
| T5 | S1-S5 docs | inline | done | `7ddcf96` |

- T1: shared session identity (`CurrentUser`) used by client/owner booking controllers, owner motels page and `MotelController.getMyMotels`; SQL to reassign demo motels.
- T2: `ReservationFirestoreDocument` + `ReservationCloudRepository` (Firestore impl) with role-scoped reads.
- T3: `firestore.rules` for `reservations` (Risk item 2: security).
- T4: synced `BookingRepository` (local write + cloud push, cloud pull per role into the cache), wired in `useDatabase()`.
- T5: `docs/modules/booking.md`, `docs/decisions_log.md`, `contexts/people/feature_daniel.feature.md` (says PQRS; user confirmed the branch owns reservations).

Route evidence: no Writer trigger (units are sequential and depend on each other); all inline.

## Log

- **L1** (2026-11-07) User: "si, empecemos con firebase" — accepting the proposal: (1) colección `reservations` en Firestore, SQLite como copia local; (2) reglas: cliente solo sus reservas, propietario solo las de sus moteles, admin todas; (3) leer desde Firestore en propietario y admin en lugar de la semilla local.
- **L2** (2026-11-07) User: "si somo reseva ya qeu hace una seas hicmos un caombio" — the branch owns reservations, not PQRS.
- **L3** Discovery: booking controllers use `demoUserId` / `demoOwnerId`; Firestore rules need the real uid, hence S4. No `fake_cloud_firestore` and new dependencies need a team decision, so Firestore code is tested through an interface fake (payments pattern) plus pure document mapping tests. Rules are deployed by the user (`firebase deploy --only firestore:rules`); no emulator test available here.
- **L4** (2026-11-07) Discovery: Supabase `motels.owner_id` holds demo ids (`owner-1020304050`, `owner-900123456`), even for motels created from the app, because `owner_motels_page.dart` and `MotelController.getMyMotels` hardcode the demo owner. Firestore rules can only match `request.auth.uid`, so owners would see nothing (payments has the same gap). User: "la 1, arregla el origen" → S5.
- **L5** (2026-11-07) T3 rules written (`match /reservations/{reservationId}`): create relaxed from `pending`-only to any valid status, because an offline-paid reservation would first sync as `upcoming` and the client can do pending→upcoming anyway. No Java in this machine, so the Firestore emulator cannot run; rules stay uncommitted until verified. Next: emulator rule tests (needs Java) or independent verifier; user deploys rules; user reassigns demo motels in Supabase.
- **L6** (2026-11-07) User: "si, instala java y prueba las reglas". Java 21 via mise; 31 Firestore emulator cases pass (harness outside the repo). Independent verifier: S2/S4 met, S3 met in code, S5 partial (Supabase SQL pending); 2 blockers in sync: B1 dates pushed with microseconds vs SQLite milliseconds → every re-push denied (createdAt looked changed); B2 pull overwrote locally unsynced changes. Fixed in `ae14170` (ms timestamps; unsynced ids keep local state and are re-pushed before pulling), RED→GREEN 3 tests, suite 483 green. Advisories not fixed (out of scope, reported to user): client-chosen ownerId/totals/status/invoiceAccessStatus are not cross-checked (same gap as payments), final states still editable in reason/payment method, shared-device local cache, rule length limits vs app inputs.
- **L7** (2026-11-07) Live Firestore rules were ahead of git (newer `users` rules from an unpushed branch); publishing the repo file would have removed them. Rebased the reservations block on the published ruleset (`bf0f8c4`, +100/-0 vs published, 31 emulator cases green); user published it. User: "si, pasalos a juan camilo" → 5 Supabase motels reassigned to `5ZweFyvTJpWUZJEAUzYjgdCDVoR2` via REST (`0a672cd`, verified 5/5 with the publishable key). Side effect: without a session the owner motels page (Supabase-backed) no longer shows the demo owner's motels.
- **L8** (2026-11-07) User: "descarga eun emulardo y creatu uan caunata pra che la peudeba". Android SDK + AVD (Pixel 7, API 36) installed; client test account `qa.reservas.claude@machuco-test.dev` (uid `RaJSCYuLrnR6JvQqFcKdlnjTjGY2`, created via Auth REST; credentials outside the repo). End-to-end on the emulator against live Firebase: create reservation → Firestore doc with guestId = test uid and ownerId = Juan Camilo; card payment → doc updated to `upcoming` / `Tarjeta` (B1 fix confirmed live); invoice FAC-000003 shown; local payment `paid`. Live rules check: own-guest query 200, other-guest query 403. Found and fixed `3748f5f`: a failed payment registration could not be retried (second Continuar re-confirmed a non-pending reservation). Findings outside this feature: default builds use hardcoded auth (`AUTH_USE_HARDCODED_AUTH_USERS` defaults to true), so no Firebase session and no sync; `PaymentRepository` has no default Supabase URL/key, so without `--dart-define` card payments fail (README says defaults exist). Not verified: owner-side view (no owner credentials); Firestore `payments` doc (client cannot read it). Test data left in Firestore: 2 reservations (rules forbid delete; console only).

