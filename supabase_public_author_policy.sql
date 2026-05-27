-- ════════════════════════════════════════════════════════════════
-- Migration: Profilnamen für Autoren öffentlicher Einträge sichtbar machen
-- Ausführen in: Supabase Dashboard → SQL Editor
-- ════════════════════════════════════════════════════════════════

-- Alte Policy ersetzen (erweitert um public-entry-Autoren)
DROP POLICY IF EXISTS "user reads own profile" ON public.profiles;

CREATE POLICY "user reads own profile" ON public.profiles
  FOR SELECT TO authenticated USING (
    -- eigenes Profil
    user_id = auth.uid()
    -- Co-Mitglieder einer gemeinsamen Gruppe
    OR EXISTS (
      SELECT 1
      FROM reise_group_members me
      JOIN reise_group_members them ON me.group_id = them.group_id
      WHERE me.user_id   = auth.uid()
        AND them.user_id = public.profiles.user_id
    )
    -- Autoren von öffentlich geteilten Einträgen
    OR EXISTS (
      SELECT 1 FROM reise_eintraege
      WHERE reise_eintraege.user_id = public.profiles.user_id
        AND reise_eintraege.is_public = true
    )
  );
