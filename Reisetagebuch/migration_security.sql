-- =============================================================
--  Reisetagebuch — Security Hardening Migration
--  Ausführen in: Supabase Dashboard → SQL Editor
--
--  SCHRITT 0: Vorher deine UUID holen!
--  → In der App einloggen, dann Browser-Konsole (F12) öffnen:
--    (await sb.auth.getUser()).data.user.id
--  → UUID unten bei 'YOUR-USER-UUID-HERE' eintragen
-- =============================================================

-- ❶ Tenancy-Spalte hinzufügen
ALTER TABLE public.reise_eintraege
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id);

-- ❷ Alle bestehenden Zeilen deinem Account zuweisen
--    ⚠ UUID ersetzen!
UPDATE public.reise_eintraege
   SET user_id = '444a1979-784e-4c86-b8a5-423dfbbb9c88'
 WHERE user_id IS NULL;

-- ❸ NOT NULL + Auto-Fill aus JWT erzwingen
ALTER TABLE public.reise_eintraege
  ALTER COLUMN user_id SET NOT NULL,
  ALTER COLUMN user_id SET DEFAULT auth.uid();

-- ❹ Legacy-Spalten mit Inline-Bildern droppen (Bug #3)
ALTER TABLE public.reise_eintraege DROP COLUMN IF EXISTS photo_base64;
ALTER TABLE public.reise_eintraege DROP COLUMN IF EXISTS photo_url;

-- ❺ RLS aktivieren
ALTER TABLE public.reise_eintraege ENABLE ROW LEVEL SECURITY;

-- Alte permissive Policies entfernen (falls vorhanden)
DROP POLICY IF EXISTS "anon all"   ON public.reise_eintraege;
DROP POLICY IF EXISTS "public all" ON public.reise_eintraege;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.reise_eintraege;
DROP POLICY IF EXISTS "Enable insert for all users"      ON public.reise_eintraege;
DROP POLICY IF EXISTS "Enable update for all users"      ON public.reise_eintraege;
DROP POLICY IF EXISTS "Enable delete for all users"      ON public.reise_eintraege;

-- Neue Policies: nur eigene Zeilen
CREATE POLICY "own rows: select" ON public.reise_eintraege
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "own rows: insert" ON public.reise_eintraege
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

CREATE POLICY "own rows: update" ON public.reise_eintraege
  FOR UPDATE TO authenticated
  USING      (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "own rows: delete" ON public.reise_eintraege
  FOR DELETE TO authenticated USING (user_id = auth.uid());

-- ❻ Storage-Bucket: public → false
UPDATE storage.buckets SET public = false WHERE id = 'trip-images';

-- Alle alten Storage-Policies für diesen Bucket entfernen
DO $$
DECLARE p RECORD;
BEGIN
  FOR p IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND (qual ILIKE '%trip-images%' OR with_check ILIKE '%trip-images%')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', p.policyname);
  END LOOP;
END $$;

-- Neue Storage-Policies: nur eigener Ordner (<uid>/...)
CREATE POLICY "trip-images: owner select" ON storage.objects
  FOR SELECT TO authenticated USING (
    bucket_id = 'trip-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "trip-images: owner insert" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (
    bucket_id = 'trip-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
    AND (metadata->>'mimetype') ~ '^(image|video)/'
  );

CREATE POLICY "trip-images: owner update" ON storage.objects
  FOR UPDATE TO authenticated USING (
    bucket_id = 'trip-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "trip-images: owner delete" ON storage.objects
  FOR DELETE TO authenticated USING (
    bucket_id = 'trip-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- =============================================================
--  VERIFIKATION — Nach Ausführen dieser Abfragen prüfen:
-- =============================================================

-- Muss genau 0 zurückgeben (kein user_id = NULL mehr):
SELECT COUNT(*) AS ohne_owner FROM public.reise_eintraege WHERE user_id IS NULL;

-- Muss die 4 neuen Policies zeigen:
SELECT policyname, cmd FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'reise_eintraege'
ORDER BY cmd;

-- Muss public = false zeigen:
SELECT id, public FROM storage.buckets WHERE id = 'trip-images';
