-- Migration: Öffentliche Einträge (Entdecken-Feed)
-- Ausführen in: Supabase Dashboard → SQL Editor

-- 1. Spalte hinzufügen
ALTER TABLE reise_eintraege
  ADD COLUMN IF NOT EXISTS is_public boolean NOT NULL DEFAULT false;

-- 2. RLS-Policy: Alle können öffentliche Einträge lesen (auch unauthenticated)
CREATE POLICY "Public entries readable by everyone"
  ON reise_eintraege FOR SELECT
  USING (is_public = true);

-- (Die bestehenden Policies für authentifizierte User bleiben unverändert)
