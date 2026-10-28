-- Migración para la tabla de moteles
CREATE TABLE IF NOT EXISTS public.motels (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  room_count INTEGER NOT NULL,
  nit TEXT UNIQUE NOT NULL,
  address TEXT NOT NULL,
  phone TEXT NOT NULL,
  description TEXT,
  general_location TEXT,
  payment_methods TEXT[],
  image_urls TEXT[],
  is_available BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE public.motels ENABLE ROW LEVEL SECURITY;

-- Políticas para anon
CREATE POLICY "Allow anon select" ON public.motels FOR SELECT TO anon USING (true);
CREATE POLICY "Allow anon insert" ON public.motels FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Allow anon update" ON public.motels FOR UPDATE TO anon USING (true) WITH CHECK (true);

-- Datos iniciales
INSERT INTO public.motels (id, owner_id, name, email, room_count, nit, address, phone, description, general_location, payment_methods, image_urls, is_available)
VALUES
  ('1', 'owner-1020304050', 'Motel Paraíso Élite', 'admin@paraisoelite.com', 15, '900123456-1', 'Calle 123 # 45-67, Rionegro', '3001234567', 'Un espacio discreto y elegante con acabados de lujo, ideal para salir de la rutina y disfrutar en pareja.', 'Rionegro - Zona Rosa', ARRAY['Efectivo','Nequi','Tarjeta'], ARRAY['url_imagen_1.jpg'], true),
  ('2', 'owner-1020304050', 'Motel El Edén', 'reservas@eleden.com', 20, '900987654-2', 'Avenida Llanogrande # 12-34', '3109876543', 'Cabañas exclusivas rodeadas de naturaleza con la mayor privacidad y servicios de primera clase.', 'Llanogrande', ARRAY['Efectivo','Transferencia'], ARRAY['url_imagen_2.jpg'], true),
  ('3', 'owner-900123456', 'Motel Eclipse', 'contacto@moteleclipse.com', 30, '900123456-3', 'Carrera 7 # 89-01, Rionegro', '3119876543', 'Económico y acogedor. El mejor servicio al mejor precio del sector.', 'Rionegro - Centro', ARRAY['Efectivo'], ARRAY[]::text[], true)
ON CONFLICT (id) DO NOTHING;
