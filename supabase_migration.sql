-- ════════════════════════════════════════════════════════════════
--  Migration: user_id + RLS für reise_eintraege
--  Ausführen in: Supabase Dashboard → SQL Editor → New Query
-- ════════════════════════════════════════════════════════════════

-- 1. user_id Spalte hinzufügen
ALTER TABLE reise_eintraege
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

-- 2. Index für Performance
CREATE INDEX IF NOT EXISTS idx_reise_eintraege_user_id ON reise_eintraege(user_id);

-- 3. RLS aktivieren
ALTER TABLE reise_eintraege ENABLE ROW LEVEL SECURITY;

-- 4. Bestehende Policies entfernen (falls welche existieren)
DROP POLICY IF EXISTS "Users see own entries"    ON reise_eintraege;
DROP POLICY IF EXISTS "Users insert own entries" ON reise_eintraege;
DROP POLICY IF EXISTS "Users update own entries" ON reise_eintraege;
DROP POLICY IF EXISTS "Users delete own entries" ON reise_eintraege;

-- 5. Neue Policies erstellen
CREATE POLICY "Users see own entries" ON reise_eintraege
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users insert own entries" ON reise_eintraege
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own entries" ON reise_eintraege
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users delete own entries" ON reise_eintraege
  FOR DELETE USING (auth.uid() = user_id);

-- ════════════════════════════════════════════════════════════════
--  OPTIONAL: Bestehende Einträge deinem Account zuweisen
--  Ersetze 'DEINE-USER-ID' mit deiner echten User-ID aus:
--  Supabase → Authentication → Users → deine E-Mail → User UID
-- ════════════════════════════════════════════════════════════════
-- UPDATE reise_eintraege SET user_id = 'DEINE-USER-ID' WHERE user_id IS NULL;
