const CACHE = 'reisetagebuch-v3';
const CORE  = [
  './Reisetagebuch.html',
  'https://cdn.tailwindcss.com',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
  'https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css',
  'https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css',
  'https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js',
  'https://cdn.jsdelivr.net/npm/chart.js',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

const CORE_URLS = new Set(CORE.map(u => u.startsWith('./') ? u.slice(2) : u));

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;

  const url = e.request.url;
  const isCore = CORE.some(c => url === c || url.endsWith(c.replace('./', '/')));

  // Only serve cached responses for known CORE assets
  if (!isCore) return;

  e.respondWith(
    caches.match(e.request).then(cached => cached || fetch(e.request))
  );
});

// ─── Web Push: Display incoming notifications ────────────────────────────
self.addEventListener('push', event => {
  let payload = { title: 'Reisetagebuch', body: '' };
  try { if (event.data) payload = event.data.json(); } catch {
    try { if (event.data) payload.body = event.data.text(); } catch {}
  }
  const title = payload.title || 'Reisetagebuch';
  const opts  = {
    body:    payload.body || '',
    icon:    payload.icon  || './icon-192.png',
    badge:   payload.badge || './icon-192.png',
    data:    { url: payload.url || './Reisetagebuch.html' },
    vibrate: [80, 40, 80],
    tag:     payload.tag || 'reise-default',
  };
  event.waitUntil(self.registration.showNotification(title, opts));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target = event.notification.data?.url || './Reisetagebuch.html';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(list => {
      for (const c of list) {
        if ('focus' in c && c.url.includes('Reisetagebuch')) return c.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow(target);
    })
  );
});
