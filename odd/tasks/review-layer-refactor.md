# Review module layer refactor

Separate the review module (domain → repository → controller → view) before
connecting Supabase/Firebase. No external storage in this feature.

## Specs

- S1. Add tests that pin the current behavior of the three review controllers
  (client, owner, admin) before refactoring.
- S2. Fix bug: "Descartar reporte" must set status to "Visible" and clear the
  report reason (today `copyWith(reportReason: null)` keeps the old reason).
- S3. Add a `ReviewRepository` contract with an in-memory implementation seeded
  from the current mock data. The three controllers share one instance, so a
  change made by one role is visible to the others (ends the "islands").
  Controllers no longer read `ReviewData` directly.
- S4. Move domain rules out of widgets: the controller (not `AddReviewSheet`)
  builds the `Review` (id, author, date); rating must be 1-5 and title/body
  non-empty; rating average lives in one place.
- S5. Unknown review ids and owners without motels must not crash the app.
- S6. Cleanup: star color via design-system token (no `Color(0xFFFFB300)` in
  views/widgets), owner/admin pages dispose controllers they create, delete
  unused `lib/models/review/review_type.dart`.
- S7. Out of scope: Supabase/Firebase, real author from Firebase Auth,
  `OwnerReviewController → MotelController` dependency (same pattern as the
  booking controllers).

## Tasks

| ID | Specs | Route | Status | Commit |
|---|---|---|---|---|
| T1 | S1, S2 | inline | done | 549096c |
| T2 | S3, S5 | inline | done | cb211df |
| T3 | S4 | worker | done | f09611f |
| T4 | S6 | worker | done | 014ef47 |

## Log

- L1 (user, 2026-11-02): "antes de eso, tenemos services? antes de tocar
  supabase o firebase revisemos arquitectura y calidad. revisa que la feature
  de marco desde el domain hasta el controller por todo el flujo este
  separado." → audit; then "si, hagamoslo" approving the 4-step plan (tests
  first, ReviewRepository, domain rules, cleanup).
- L2 (close, 2026-11-02): all tasks done. Full suite: 290 passed, 1 skipped.
  Not done (S7): real author from Firebase Auth, storage backend, pages
  still call loadReviews on injected controllers.
