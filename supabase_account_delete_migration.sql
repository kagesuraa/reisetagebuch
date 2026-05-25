-- ════════════════════════════════════════════════════════════════
--  Migration: delete_my_account() RPC
--  Reihenfolge: nach den Profil/Gruppen-Migrationen ausführen.
-- ════════════════════════════════════════════════════════════════
--
-- Supabase-Clients können nicht direkt aus auth.users löschen
-- (Admin-API). Eine SECURITY DEFINER Funktion läuft mit postgres-
-- Rechten und kann das. Sie löscht ausschließlich auth.uid() —
-- ein User kann also nur sich selbst löschen. Alle abhängigen
-- Tabellen (profiles, reise_groups, _members, _invitations,
-- reise_eintraege) räumen via ON DELETE CASCADE automatisch.

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
