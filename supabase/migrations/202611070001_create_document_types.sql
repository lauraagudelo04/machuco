-- Maestro de tipos de documento que alimenta el formulario de propietarios.
--
-- Los datos de dominio (propietarios) viven en Firestore; este catálogo es un
-- maestro y por eso se publica en Supabase, tal como los indicativos
-- telefónicos. La app lo consulta por REST y lo cachea en SQLite
-- (`document_types`) para poder usarlo sin conexión.

create table if not exists public.document_types (
  id integer primary key,
  code text not null unique check (length(trim(code)) > 0),
  name text not null check (length(trim(name)) > 0),
  pattern text not null,
  example text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0
);

alter table public.document_types enable row level security;

grant select on table public.document_types to anon, authenticated;

drop policy if exists "Public can read document types"
  on public.document_types;
create policy "Public can read document types"
  on public.document_types
  for select
  to anon, authenticated
  using (true);

insert into public.document_types
  (id, code, name, pattern, example, is_active, sort_order)
values
  (1, 'CC', 'Cédula de ciudadanía', '^\d{6,10}$', '1020304050', true, 1),
  (2, 'CE', 'Cédula de extranjería', '^\d{6,12}$', '345678', true, 2),
  (3, 'NIT', 'Número de identificación tributaria', '^\d{9,10}(-\d)?$',
   '900123456-7', true, 3),
  (4, 'PAS', 'Pasaporte', '^[A-Za-z0-9]{6,12}$', 'AV123456', true, 4),
  (5, 'TI', 'Tarjeta de identidad', '^\d{6,11}$', '1020304050', true, 5)
on conflict (id) do update set
  code = excluded.code,
  name = excluded.name,
  pattern = excluded.pattern,
  example = excluded.example,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;
