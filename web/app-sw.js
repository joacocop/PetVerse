/* PV12: worker de la PWA, independiente del scope de Firebase Messaging.
 * prepare_web.mjs sustituye la versión por un hash del build publicado.
 * Solo cachea recursos estáticos públicos. Nunca Auth, Firestore, chats o medios.
 */
const VERSION = '__PETVERSE_BUILD__';
const CACHE = `petverse-public-${VERSION}`;
const ROOT = new URL('./', self.location.href);
const local = path => new URL(path, ROOT).href;
const OFFLINE = local('offline.html');
const STATIC = new Set(['manifest.json', 'pwa.js', 'offline.html',
  'icons/icon-192.png', 'icons/icon-512.png', 'icons/maskable-192.png',
  'icons/maskable-512.png', 'icons/apple-touch-icon.png']);
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll([...STATIC].map(local))));
  // Sin skipWaiting: no mezcla versiones mientras haya pestañas antiguas abiertas.
});
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter(name => name.startsWith('petverse-public-') && name !== CACHE)
      .map(name => caches.delete(name)));
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== ROOT.origin || !url.href.startsWith(ROOT.href)) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).catch(async () =>
      (await caches.match(OFFLINE)) || new Response('PetVerse necesita conexión.', {
        status: 503, headers: {'Content-Type': 'text/plain; charset=utf-8'} })));
    return;
  }
  const path = url.pathname.slice(ROOT.pathname.length);
  if (!STATIC.has(path)) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    try {
      const fresh = await fetch(event.request);
      if (fresh.ok) await cache.put(event.request, fresh.clone());
      return fresh;
    } catch (_) { return (await cache.match(event.request)) || Response.error(); }
  })());
});
