-- Demo motels were owned by placeholder ids (owner-1020304050,
-- owner-900123456), so Firestore rules based on request.auth.uid could never
-- authorize a real owner. Reassign them to the active owner account of
-- Juan Camilo Garcia (Firebase uid below). Data change only; idempotent.
update public.motels
set owner_id = '5ZweFyvTJpWUZJEAUzYjgdCDVoR2'
where owner_id in ('owner-1020304050', 'owner-900123456');
