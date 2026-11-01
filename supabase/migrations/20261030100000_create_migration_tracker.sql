-- ==============================================================================
-- SYUPEO DATABASE MIGRATION SYSTEM
-- Migration: 20261030100000_create_migration_tracker.sql
-- Description: Membuat tabel registri audit migrasi internal Syupeo
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public._syupeo_migrations (
  version VARCHAR(255) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  applied_by TEXT DEFAULT current_user
);

-- Aktifkan RLS
ALTER TABLE public._syupeo_migrations ENABLE ROW LEVEL SECURITY;

-- Hanya Admin / Service Role yang dapat melihat riwayat migrasi
DROP POLICY IF EXISTS "Admins can view migrations" ON public._syupeo_migrations;
CREATE POLICY "Admins can view migrations"
  ON public._syupeo_migrations
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users
      WHERE email = lower(auth.jwt() ->> 'email')
        AND is_active = true
    ) OR (lower(auth.jwt() ->> 'email') = 'diyanto2911@gmail.com')
  );

-- Catat migrasi ini sendiri
INSERT INTO public._syupeo_migrations (version, name, description)
VALUES (
  '20261030100000',
  'create_migration_tracker',
  'Inisialisasi tabel audit registri migrasi database Syupeo'
)
ON CONFLICT (version) DO NOTHING;

