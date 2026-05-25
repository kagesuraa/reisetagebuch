-- ════════════════════════════════════════════════════════════════
--  Migration: trip-images sichtbar machen für Gruppen-Co-Mitglieder
--  Reihenfolge: nach supabase_groups_migration.sql ausführen.
-- ════════════════════════════════════════════════════════════════
--
-- Problem: Bucket „trip-images" ist privat und die SELECT-Policy
-- erlaubt nur dem Eigentümer das Lesen der eigenen Storage-Objekte.
-- Damit funktionieren createSignedUrl-Calls für fremde Bilder
-- (z. B. von Gruppen-Mitgliedern) nicht — Fotos in geteilten
-- Einträgen bleiben unsichtbar.
--
-- Fix: Zusätzliche SELECT-Policy, die einen Storage-Object lesbar
-- macht, sobald er von irgendeinem Eintrag referenziert wird, den
-- ich per RLS auf reise_eintraege sehen darf. Die EXISTS-Subquery
-- filtert automatisch via Entry-RLS — keine Doppellogik nötig.

DROP POLICY IF EXISTS "trip-images: entries i can see" ON storage.objects;

CREATE POLICY "trip-images: entries i can see" ON storage.objects
  FOR SELECT TO authenticated USING (
    bucket_id = 'trip-images'
    AND EXISTS (
      SELECT 1 FROM public.reise_eintraege e
      WHERE e.image_url IS NOT NULL
        AND e.image_url LIKE '%' || storage.objects.name || '%'
    )
  );
