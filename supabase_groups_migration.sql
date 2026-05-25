-- ════════════════════════════════════════════════════════════════
--  Migration: Gruppen-System (Tabellen, Helper, RLS)
--  Ausführen in: Supabase Dashboard → SQL Editor → New Query
--  Voraussetzung: supabase_migration.sql wurde bereits ausgeführt
-- ════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────────
-- 1. Tabellen
-- ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS reise_groups (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 60),
  created_by  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reise_group_members (
  group_id   uuid NOT NULL REFERENCES reise_groups(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role       text NOT NULL CHECK (role IN ('admin','member')),
  joined_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reise_group_members_user ON reise_group_members(user_id);

CREATE TABLE IF NOT EXISTS reise_group_invitations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    uuid NOT NULL REFERENCES reise_groups(id) ON DELETE CASCADE,
  email       text NOT NULL CHECK (email = lower(email)),
  invited_by  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (group_id, email)
);

CREATE INDEX IF NOT EXISTS idx_reise_group_invitations_email ON reise_group_invitations(email) WHERE status = 'pending';

-- group_id auf bestehende Einträge — nullable, NULL = privat
ALTER TABLE reise_eintraege
  ADD COLUMN IF NOT EXISTS group_id uuid REFERENCES reise_groups(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_reise_eintraege_group ON reise_eintraege(group_id);

-- ────────────────────────────────────────────────────────────────
-- 2. SECURITY DEFINER helpers (umgehen RLS, brechen Rekursion)
-- ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_group_member(g uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM reise_group_members
    WHERE group_id = g AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_group_admin(g uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM reise_group_members
    WHERE group_id = g AND user_id = auth.uid() AND role = 'admin'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_group_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_group_admin(uuid)  TO authenticated;

-- ────────────────────────────────────────────────────────────────
-- 3. RLS aktivieren
-- ────────────────────────────────────────────────────────────────

ALTER TABLE reise_groups            ENABLE ROW LEVEL SECURITY;
ALTER TABLE reise_group_members     ENABLE ROW LEVEL SECURITY;
ALTER TABLE reise_group_invitations ENABLE ROW LEVEL SECURITY;

-- ────────────────────────────────────────────────────────────────
-- 4. Policies: reise_groups
-- ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "members read groups"     ON reise_groups;
DROP POLICY IF EXISTS "anyone create group"     ON reise_groups;
DROP POLICY IF EXISTS "admins update group"     ON reise_groups;
DROP POLICY IF EXISTS "admins delete group"     ON reise_groups;

CREATE POLICY "members read groups" ON reise_groups
  FOR SELECT USING (public.is_group_member(id));

CREATE POLICY "anyone create group" ON reise_groups
  FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "admins update group" ON reise_groups
  FOR UPDATE USING (public.is_group_admin(id));

CREATE POLICY "admins delete group" ON reise_groups
  FOR DELETE USING (public.is_group_admin(id));

-- ────────────────────────────────────────────────────────────────
-- 5. Policies: reise_group_members
-- ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "members read members"        ON reise_group_members;
DROP POLICY IF EXISTS "creator self-insert"         ON reise_group_members;
DROP POLICY IF EXISTS "invitee self-join"           ON reise_group_members;
DROP POLICY IF EXISTS "admins update member roles"  ON reise_group_members;
DROP POLICY IF EXISTS "self leave or admin remove"  ON reise_group_members;

CREATE POLICY "members read members" ON reise_group_members
  FOR SELECT USING (public.is_group_member(group_id));

-- Beim Erstellen einer Gruppe trägt der Creator sich selbst als Admin ein
CREATE POLICY "creator self-insert" ON reise_group_members
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (SELECT 1 FROM reise_groups g WHERE g.id = group_id AND g.created_by = auth.uid())
  );

-- Ein Eingeladener akzeptiert selbst die Einladung
CREATE POLICY "invitee self-join" ON reise_group_members
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND role = 'member'
    AND EXISTS (
      SELECT 1 FROM reise_group_invitations i
      WHERE i.group_id = reise_group_members.group_id
        AND i.email   = lower(auth.jwt() ->> 'email')
        AND i.status  = 'pending'
    )
  );

CREATE POLICY "admins update member roles" ON reise_group_members
  FOR UPDATE USING (public.is_group_admin(group_id));

CREATE POLICY "self leave or admin remove" ON reise_group_members
  FOR DELETE USING (user_id = auth.uid() OR public.is_group_admin(group_id));

-- ────────────────────────────────────────────────────────────────
-- 6. Policies: reise_group_invitations
-- ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "invitee or admin read"   ON reise_group_invitations;
DROP POLICY IF EXISTS "admins create invites"   ON reise_group_invitations;
DROP POLICY IF EXISTS "invitee or admin update" ON reise_group_invitations;
DROP POLICY IF EXISTS "invitee or admin delete" ON reise_group_invitations;

CREATE POLICY "invitee or admin read" ON reise_group_invitations
  FOR SELECT USING (
    public.is_group_admin(group_id)
    OR email = lower(auth.jwt() ->> 'email')
  );

CREATE POLICY "admins create invites" ON reise_group_invitations
  FOR INSERT WITH CHECK (public.is_group_admin(group_id));

CREATE POLICY "invitee or admin update" ON reise_group_invitations
  FOR UPDATE USING (
    public.is_group_admin(group_id)
    OR email = lower(auth.jwt() ->> 'email')
  );

CREATE POLICY "invitee or admin delete" ON reise_group_invitations
  FOR DELETE USING (
    public.is_group_admin(group_id)
    OR email = lower(auth.jwt() ->> 'email')
  );

-- ────────────────────────────────────────────────────────────────
-- 7. Policies: reise_eintraege — Gruppen-Sichtbarkeit ergänzen
--    (alte Owner-only Policy ersetzen)
-- ────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "Users see own entries"    ON reise_eintraege;
DROP POLICY IF EXISTS "Users insert own entries" ON reise_eintraege;
DROP POLICY IF EXISTS "Users update own entries" ON reise_eintraege;
DROP POLICY IF EXISTS "Users delete own entries" ON reise_eintraege;

CREATE POLICY "owner or group member read" ON reise_eintraege
  FOR SELECT USING (
    auth.uid() = user_id
    OR (group_id IS NOT NULL AND public.is_group_member(group_id))
  );

CREATE POLICY "owner insert" ON reise_eintraege
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND (group_id IS NULL OR public.is_group_member(group_id))
  );

CREATE POLICY "owner update" ON reise_eintraege
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND (group_id IS NULL OR public.is_group_member(group_id))
  );

CREATE POLICY "owner delete" ON reise_eintraege
  FOR DELETE USING (auth.uid() = user_id);
