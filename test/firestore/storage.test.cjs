const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { ref, uploadBytes, uploadBytesResumable, getBytes, getDownloadURL, deleteObject } = require('firebase/storage');
let env;
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-petverse-tests', storage: {
    host: '127.0.0.1', port: 9195, rules: readFileSync(resolve(__dirname, '../../storage.rules'), 'utf8') } });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => { await env.clearStorage(); });
const storage = (uid) => env.authenticatedContext(uid).storage('gs://demo-petverse-tests.appspot.com');

test('Upload con progreso y URL; solo propietario escribe, contenido y tamaño restringidos', async () => {
  const alice = storage('alice'); const bob = storage('bob');
  const target = ref(alice, 'users/alice/media/image.jpg');
  const upload = uploadBytesResumable(target, new Uint8Array(1024), { contentType: 'image/jpeg' });
  const progress = [];
  upload.on('state_changed', s => progress.push(s.bytesTransferred / s.totalBytes));
  await assertSucceeds(upload);
  assert.equal(progress.at(-1), 1);
  assert.match(await getDownloadURL(target), /^http:\/\/127\.0\.0\.1:9195\//);
  assert.equal((await assertSucceeds(getBytes(ref(bob, target.fullPath)))).byteLength, 1024);
  await assertFails(uploadBytes(ref(bob, 'users/alice/media/foreign.jpg'), new Uint8Array(1), { contentType: 'image/jpeg' }));
  await assertFails(deleteObject(ref(bob, target.fullPath)));
  await assertFails(uploadBytes(ref(alice, 'users/alice/media/script.html'), new Uint8Array(1), { contentType: 'text/html' }));
  await assertFails(uploadBytes(ref(alice, 'users/alice/media/large.jpg'), new Uint8Array(10 * 1024 * 1024 + 1), { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(alice, 'users/alice/media/empty.jpg'), new Uint8Array(0), { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(target, new Uint8Array(1), { contentType: 'image/jpeg' }));
  await assertSucceeds(uploadBytes(ref(alice, 'users/alice/media/video.mp4'), new Uint8Array(1024), { contentType: 'video/mp4' }));
  const visitor = env.unauthenticatedContext().storage('gs://demo-petverse-tests.appspot.com');
  await assertFails(getBytes(ref(visitor, target.fullPath)));
  await assertSucceeds(deleteObject(target));
});
