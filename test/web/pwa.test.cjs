const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const vm = require('node:vm');
const root = resolve(__dirname, '../..');

function browser() {
  const events = {};
  const window = { isSecureContext: true, matchMedia: () => ({ matches: false, addEventListener() {} }),
    addEventListener: (type, callback) => { events[type] = callback; } };
  const context = { window, navigator: { userAgent: 'Chrome' } };
  vm.runInNewContext(readFileSync(resolve(root, 'web/pwa.js'), 'utf8'), context);
  return { window, events };
}
test('Manifest e iconos PNG reales con dimensiones válidas y safe area separada', () => {
  const manifest = JSON.parse(readFileSync(resolve(root, 'web/manifest.json')));
  assert.equal(manifest.display, 'standalone'); assert.ok(manifest.id); assert.ok(manifest.scope);
  for (const icon of manifest.icons) {
    const png = readFileSync(resolve(root, 'web', icon.src));
    assert.equal(png.readUInt32BE(16), Number(icon.sizes.split('x')[0]));
    assert.equal(png.readUInt32BE(20), Number(icon.sizes.split('x')[1]));
  }
  assert.ok(manifest.icons.some(i => i.purpose === 'maskable' && i.sizes === '512x512'));
  const bootstrap = readFileSync(resolve(root, 'web/flutter_bootstrap.js'), 'utf8');
  assert.ok(bootstrap.includes('_flutter.loader.load();'));
  assert.ok(!bootstrap.includes('serviceWorkerSettings'));
});
test('El prompt conserva el gesto, respeta cancelación y espera appinstalled', async () => {
  const { window, events } = browser(); let prompted = 0; let prevented = false;
  events.beforeinstallprompt({ preventDefault() { prevented = true; },
    prompt() { prompted++; return Promise.resolve(); }, userChoice: Promise.resolve({ outcome: 'accepted' }) });
  assert.equal(prevented, true); assert.equal(window.petversePwaState(), 'available');
  const result = window.petversePwaInstall();
  assert.equal(prompted, 1); assert.equal(await result, 'accepted');
  assert.equal(window.petversePwaState(), 'manual');
  events.appinstalled(); assert.equal(window.petversePwaState(), 'installed');
  const second = browser();
  second.events.beforeinstallprompt({ preventDefault() {}, prompt() {}, userChoice: Promise.resolve({ outcome: 'dismissed' }) });
  assert.equal(await second.window.petversePwaInstall(), 'dismissed');
  assert.equal(second.window.petversePwaState(), 'manual');
});
test('Worker no intercepta Auth, Firestore, chats, medios, POST ni worker FCM', async () => {
  const handlers = {}; const cached = [];
  const self = { location: { href: 'https://petverse.example/app-sw.js' },
    addEventListener: (name, callback) => { handlers[name] = callback; }, clients: { claim: async () => {} } };
  const cache = { addAll: async urls => cached.push(...urls) };
  vm.runInNewContext(readFileSync(resolve(root, 'web/app-sw.js'), 'utf8'), {
    self, URL, Response, caches: { open: async () => cache }, fetch,
  });
  let install;
  handlers.install({ waitUntil(promise) { install = promise; } }); await install;
  assert.ok(cached.some(url => url.endsWith('/offline.html')));
  assert.ok(!cached.some(url => url.includes('main.dart.js')));
  for (const url of ['https://firestore.googleapis.com/v1/data',
    'https://identitytoolkit.googleapis.com/token', 'https://petverse.example/chats/private',
    'https://petverse.example/firebase-messaging-sw.js', 'https://petverse.example/media/foto.jpg']) {
    let intercepted = false;
    handlers.fetch({ request: { url, method: 'GET', mode: 'cors' }, respondWith() { intercepted = true; } });
    assert.equal(intercepted, false, url);
  }
  let intercepted = false;
  handlers.fetch({ request: { url: 'https://petverse.example/pwa.js', method: 'POST' }, respondWith() { intercepted = true; } });
  assert.equal(intercepted, false);
});
