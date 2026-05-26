-- ════════════════════════════════════════════════════════════════
--  Migration: push_subscriptions für Web Push Notifications
--  Ausführen in: Supabase Dashboard → SQL Editor → New Query
-- ════════════════════════════════════════════════════════════════

-- 1. Tabelle für Browser-Push-Subscriptions
CREATE TABLE IF NOT EXISTS reise_push_subscriptions (
  id           uuid       PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid       NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint     text       NOT NULL UNIQUE,
  p256dh       text       NOT NULL,
  auth_key     text       NOT NULL,
  user_agent   text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reise_push_user_id
  ON reise_push_subscriptions(user_id);

-- 2. RLS: Nur eigene Subscriptions sichtbar / verwaltbar
ALTER TABLE reise_push_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "push: select own"   ON reise_push_subscriptions;
DROP POLICY IF EXISTS "push: insert own"   ON reise_push_subscriptions;
DROP POLICY IF EXISTS "push: update own"   ON reise_push_subscriptions;
DROP POLICY IF EXISTS "push: delete own"   ON reise_push_subscriptions;

CREATE POLICY "push: select own" ON reise_push_subscriptions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "push: insert own" ON reise_push_subscriptions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "push: update own" ON reise_push_subscriptions
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "push: delete own" ON reise_push_subscriptions
  FOR DELETE USING (auth.uid() = user_id);

-- ════════════════════════════════════════════════════════════════
-- NÄCHSTE SCHRITTE (außerhalb dieser Datei):
-- 1. VAPID-Keys generieren (z.B. `npx web-push generate-vapid-keys`)
-- 2. Public Key in der App eintragen: window.VAPID_PUBLIC_KEY
-- 3. Edge Function deployen, die Push-Notifications via web-push verschickt
--    (Beispiel: supabase/functions/send-push/index.ts)
-- ════════════════════════════════════════════════════════════════
