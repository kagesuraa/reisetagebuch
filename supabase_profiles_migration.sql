-- ════════════════════════════════════════════════════════════════
--  Migration: public.profiles + auth.users sync trigger + Lookup-RPC
--  Reihenfolge: nach supabase_groups_migration.sql ausführen
--  Zweck: Group-Invites per Benutzername ODER E-Mail mit Existenz-
--  Validierung. Kein direktes Lesen von auth.users vom Client; alle
--  Lookups laufen über die SECURITY DEFINER Funktion unten.
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.profiles (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email      text NOT NULL,
  username   text UNIQUE,
  avatar_url text,
  color      text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT profiles_email_lowercase CHECK (email = lower(email)),
  CONSTRAINT profiles_username_format CHECK (
    username IS NULL OR username ~ '^[a-zA-Z0-9_.-]{3,30}$'
  ),
  CONSTRAINT profiles_color_format CHECK (
    color IS NULL OR color ~* '^#[0-9a-f]{6}$'
  )
);

-- Falls Tabelle aus früheren Migrationen ohne diese Spalten existiert
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS color      text;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_color_format;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_color_format
  CHECK (color IS NULL OR color ~* '^#[0-9a-f]{6}$');

CREATE INDEX IF NOT EXISTS idx_profiles_email    ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username) WHERE username IS NOT NULL;

CREATE OR REPLACE FUNCTION public.sync_profile_from_auth()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  INSERT INTO public.profiles (user_id, email)
  VALUES (NEW.id, lower(NEW.email))
  ON CONFLICT (user_id) DO UPDATE SET email = EXCLUDED.email, updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_profile_on_user_change ON auth.users;
CREATE TRIGGER sync_profile_on_user_change
  AFTER INSERT OR UPDATE OF email ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.sync_profile_from_auth();

INSERT INTO public.profiles (user_id, email)
SELECT id, lower(email) FROM auth.users
WHERE email IS NOT NULL
ON CONFLICT (user_id) DO NOTHING;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user reads own profile"    ON public.profiles;
DROP POLICY IF EXISTS "user updates own profile"  ON public.profiles;
DROP POLICY IF EXISTS "user inserts own profile"  ON public.profiles;

-- Eigene Daten + Co-Mitglieder einer geteilten Gruppe (für Autor-Namen +
-- per-User-Farbe auf der Karte).
CREATE POLICY "user reads own profile" ON public.profiles
  FOR SELECT TO authenticated USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM reise_group_members me
      JOIN reise_group_members them ON me.group_id = them.group_id
      WHERE me.user_id   = auth.uid()
        AND them.user_id = public.profiles.user_id
    )
  );

CREATE POLICY "user updates own profile" ON public.profiles
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "user inserts own profile" ON public.profiles
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

-- SECURITY DEFINER lookup: löst Username ODER E-Mail zu kanonischer
-- E-Mail auf. Verhindert, dass alle Profile gelistet werden können.
CREATE OR REPLACE FUNCTION public.find_user_email_by_identifier(identifier text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT email FROM public.profiles
  WHERE email = lower(trim(identifier))
     OR username = trim(identifier)
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.find_user_email_by_identifier(text) TO authenticated;

-- my_email(): kanonische E-Mail des aktuellen Users; stabiler als
-- auth.jwt() ->> 'email' (Mail-Claim ist nicht immer im Token).
-- Wird von Gruppen-Policies (RLS) gebraucht.
CREATE OR REPLACE FUNCTION public.my_email()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT email FROM public.profiles WHERE user_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.my_email() TO authenticated;
