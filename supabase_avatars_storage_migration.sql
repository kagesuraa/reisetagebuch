-- ════════════════════════════════════════════════════════════════
--  Migration: Storage-Bucket „avatars" + RLS
--  Reihenfolge: nach supabase_profiles_migration.sql ausführen.
--  Pfad-Konvention: avatars/<auth.uid()>/<filename>
-- ════════════════════════════════════════════════════════════════

-- 1. Öffentlicher Bucket „avatars"
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. RLS-Policies auf storage.objects für „avatars"
DROP POLICY IF EXISTS "avatars public read"  ON storage.objects;
DROP POLICY IF EXISTS "avatars owner write"  ON storage.objects;
DROP POLICY IF EXISTS "avatars owner update" ON storage.objects;
DROP POLICY IF EXISTS "avatars owner delete" ON storage.objects;

-- Lesen darf jeder (Bucket ist public).
CREATE POLICY "avatars public read" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'avatars');

-- Schreiben/Ersetzen/Löschen nur unter eigenem User-ID-Präfix.
CREATE POLICY "avatars owner write" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "avatars owner update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "avatars owner delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
