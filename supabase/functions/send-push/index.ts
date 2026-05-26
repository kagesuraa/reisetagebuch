// Supabase Edge Function: send-push
// Schickt eine Web-Push-Benachrichtigung an die Subscriptions eines Users.
//
// Einrichtung:
//   1. `npx web-push generate-vapid-keys` lokal ausführen
//   2. In Supabase → Edge Functions → Secrets:
//        - VAPID_PUBLIC_KEY    (gleicher Wert wie window.VAPID_PUBLIC_KEY in der App)
//        - VAPID_PRIVATE_KEY
//        - VAPID_SUBJECT       (z.B. "mailto:you@example.com")
//   3. `supabase functions deploy send-push`
//
// Aufruf (z.B. aus einem DB-Trigger oder Server-Client):
//   POST /functions/v1/send-push
//   Body: { "user_id": "<uuid>", "title": "Neuer Eintrag", "body": "Anna hat ...", "url": "/" }
//
// Auth: Service-Role-Key im Authorization-Header verwenden.

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import webpush from 'https://esm.sh/web-push@3.6.7';

const SUPABASE_URL  = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const VAPID_PUBLIC  = Deno.env.get('VAPID_PUBLIC_KEY')!;
const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE_KEY')!;
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') || 'mailto:admin@example.com';

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

const sb = createClient(SUPABASE_URL, SERVICE_KEY);

serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  let payload: { user_id?: string; title?: string; body?: string; url?: string; tag?: string };
  try { payload = await req.json(); } catch { return new Response('Invalid JSON', { status: 400 }); }

  const { user_id, title = 'Reisetagebuch', body = '', url = '/', tag } = payload;
  if (!user_id) return new Response('Missing user_id', { status: 400 });

  const { data: subs, error } = await sb
    .from('reise_push_subscriptions')
    .select('id,endpoint,p256dh,auth_key')
    .eq('user_id', user_id);

  if (error)  return new Response('DB error: ' + error.message, { status: 500 });
  if (!subs?.length) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  const notification = JSON.stringify({ title, body, url, tag });
  let sent = 0, removed = 0;

  await Promise.all(subs.map(async (s) => {
    const sub = { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth_key } };
    try {
      await webpush.sendNotification(sub, notification);
      sent++;
    } catch (e: any) {
      // 404 / 410 = Subscription abgelaufen → Tabelle aufräumen
      if (e?.statusCode === 404 || e?.statusCode === 410) {
        await sb.from('reise_push_subscriptions').delete().eq('id', s.id);
        removed++;
      }
    }
  }));

  return new Response(JSON.stringify({ sent, removed, total: subs.length }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
});
