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
| T1 | S4, S5 | inline | pending | |
| T2 | S1 | inline | pending | |
| T3 | S2 | inline | pending | |
| T4 | S1, S3 | inline | pending | |
| T5 | S1-S4 docs | inline | pending | |

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
