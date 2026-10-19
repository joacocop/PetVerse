const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { before, after, beforeEach, test } = require('node:test');
const { strict: assert } = require('node:assert');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, getDoc, getDocs, collection,
  query, orderBy, arrayUnion, arrayRemove, serverTimestamp, onSnapshot } = require('firebase/firestore');

let env;
const post = () => ({
  ownerId: 'alice', authorName: 'Alice', authorPhotoUrl: '',
  petId: 'luna', petName: 'Luna', imageUrl: 'https://example.com/luna.jpg',
  mediaType: 'image', caption: 'Luna de paseo', likes: [], createdAt: serverTimestamp(),
});
const comment = (userId, text = '¡Qué linda!') => ({
  userId, userName: userId, userPhotoUrl: '', text, createdAt: serverTimestamp(),
});
const db = (id) => env.authenticatedContext(id).firestore();
const postRef = (client) => doc(client, 'posts/p1');
const commentRef = (client) => doc(client, 'posts/p1/comments/c1');

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-petverse-tests',
    firestore: { host: '127.0.0.1', port: 8085,
      rules: readFileSync(resolve(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/alice/pets/luna'), { name: 'Luna' });
  });
  await assertSucceeds(setDoc(postRef(db('alice')), post()));
});

test('La comunidad autenticada lee el feed; visitantes y mascotas ajenas no', async () => {
  const bob = db('bob');
  await assertSucceeds(getDocs(query(collection(bob, 'posts'), orderBy('createdAt', 'desc'))));
  await assertFails(getDoc(postRef(env.unauthenticatedContext().firestore())));
  await assertFails(setDoc(doc(bob, 'posts/forged'), post()));
  await assertFails(setDoc(doc(bob, 'posts/foreignPet'), { ...post(), ownerId: 'bob' }));
  await assertFails(getDoc(doc(bob, 'users/alice/pets/luna')));
});

test('Likes concurrentes e idempotentes preservan las reacciones ajenas', async () => {
  const alice = db('alice');
  const bob = db('bob');
  await Promise.all([
    assertSucceeds(updateDoc(postRef(alice), { likes: arrayUnion('alice') })),
    assertSucceeds(updateDoc(postRef(bob), { likes: arrayUnion('bob') })),
  ]);
  await assertSucceeds(updateDoc(postRef(bob), { likes: arrayUnion('bob') }));
  assert.deepEqual(new Set((await getDoc(postRef(bob))).data().likes), new Set(['alice', 'bob']));
  await assertFails(updateDoc(postRef(bob), { likes: arrayRemove('alice') }));
  await assertFails(updateDoc(postRef(bob), { likes: arrayUnion('mallory') }));
  await assertFails(updateDoc(postRef(bob), { caption: 'Texto falsificado' }));
  await assertFails(updateDoc(postRef(bob), { likes: ['alice', 'bob', 'bob'] }));
  await assertSucceeds(updateDoc(postRef(bob), { likes: arrayRemove('bob') }));
  assert.deepEqual((await getDoc(postRef(alice))).data().likes, ['alice']);
});

test('Comentarios visibles por todos y eliminación exclusiva del autor', async () => {
  const alice = db('alice');
  const bob = db('bob');
  await assertSucceeds(setDoc(commentRef(bob), comment('bob')));
  await assertSucceeds(getDocs(query(collection(alice, 'posts/p1/comments'), orderBy('createdAt'))));
  await assertFails(deleteDoc(commentRef(alice)));
  await assertFails(setDoc(doc(alice, 'posts/p1/comments/forged'), comment('bob')));
  await assertFails(updateDoc(commentRef(bob), { text: 'Edición no permitida' }));
  await assertFails(setDoc(doc(bob, 'posts/missing/comments/c1'), comment('bob')));
  await assertFails(setDoc(doc(bob, 'posts/p1/comments/empty'), comment('bob', '')));
  await assertFails(setDoc(doc(bob, 'posts/p1/comments/long'), comment('bob', 'a'.repeat(1001))));
  await assertSucceeds(deleteDoc(commentRef(bob)));
});

test('Dos clientes reciben likes y comentarios sin volver a consultar', async () => {
  const alice = db('alice');
  const bob = db('bob');
  const states = [{ likes: null, comments: null }, { likes: null, comments: null }];
  const errors = [];
  const subscriptions = [alice, bob].flatMap((client, index) => [
    onSnapshot(postRef(client), (snapshot) => {
      states[index].likes = snapshot.data().likes;
    }, (error) => errors.push(error)),
    onSnapshot(collection(client, 'posts/p1/comments'), (snapshot) => {
      states[index].comments = snapshot.docs.map((item) => item.data().text);
    }, (error) => errors.push(error)),
  ]);
  async function until(check) {
    const deadline = Date.now() + 8000;
    while (!check()) {
      if (errors.length) throw errors[0];
      assert.ok(Date.now() < deadline, 'No se recibió el snapshot esperado');
      await new Promise((done) => setTimeout(done, 20));
    }
  }
  try {
    await until(() => states.every((state) => state.likes && state.comments));
    await updateDoc(postRef(bob), { likes: arrayUnion('bob') });
    await until(() => states.every((state) => state.likes.includes('bob')));
    await setDoc(commentRef(bob), comment('bob', 'En tiempo real'));
    await until(() => states.every((state) => state.comments.includes('En tiempo real')));
    await deleteDoc(commentRef(bob));
    await until(() => states.every((state) => state.comments.length === 0));
  } finally {
    subscriptions.forEach((unsubscribe) => unsubscribe());
  }
});
