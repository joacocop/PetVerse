const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { before, after, beforeEach, test } = require('node:test');
const { strict: assert } = require('node:assert');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, getDoc, getDocs, collection,
  query, orderBy, where, writeBatch, arrayUnion, arrayRemove, serverTimestamp, onSnapshot } = require('firebase/firestore');

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

const adoption = () => ({ ownerId: 'alice', petId: 'luna', name: 'Luna', type: 'dog',
  breed: '', age: 2, weight: 8, photos: [], bio: 'Tranquila', ownerName: 'Alice',
  location: 'Córdoba', requirements: 'Hogar responsable', active: true, createdAt: serverTimestamp() });
const chatData = () => ({ participants: ['alice', 'bob'], createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(), lastText: '', lastSenderId: '', lastMessageId: '' });
function sendMessage(client, senderId, text, messageId = 'm1') {
  const batch = writeBatch(client);
  batch.set(doc(client, `chats/c1/messages/${messageId}`), { senderId, text, timestamp: serverTimestamp() });
  batch.update(doc(client, 'chats/c1'), { lastText: text, lastSenderId: senderId,
    lastMessageId: messageId, updatedAt: serverTimestamp() });
  return batch.commit();
}

test('Adopciones: publicar mascota propia, filtros públicos autenticados y cierre exclusivo', async () => {
  const alice = db('alice'); const bob = db('bob');
  await assertSucceeds(setDoc(doc(alice, 'adoptions/a1'), adoption()));
  await assertSucceeds(getDocs(query(collection(bob, 'adoptions'), orderBy('createdAt', 'desc'))));
  await assertFails(setDoc(doc(bob, 'adoptions/fake'), { ...adoption(), ownerId: 'bob' }));
  await assertFails(updateDoc(doc(bob, 'adoptions/a1'), { active: false }));
  await assertFails(updateDoc(doc(alice, 'adoptions/a1'), { ownerId: 'bob' }));
  await assertFails(setDoc(doc(alice, 'adoptions/invalid'), { ...adoption(), age: -1 }));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'adoptions/a1')));
  await assertSucceeds(updateDoc(doc(alice, 'adoptions/a1'), { active: false }));
});

test('Directorio mínimo público; emails, tokens e historial de avisos privados', async () => {
  const alice = db('alice'); const bob = db('bob');
  await assertSucceeds(setDoc(doc(alice, 'publicProfiles/alice'), { name: 'Alice', photoUrl: '' }));
  await assertSucceeds(getDocs(collection(bob, 'publicProfiles')));
  await assertFails(setDoc(doc(bob, 'publicProfiles/alice'), { name: 'Falso', photoUrl: '' }));
  await assertFails(setDoc(doc(alice, 'publicProfiles/alice'), { name: 'Alice', photoUrl: '', email: 'privado@example.com' }));
  await assertSucceeds(setDoc(doc(alice, 'users/alice/devices/d1'), {
    token: 'fake-token-only-for-test', updatedAt: serverTimestamp(), platform: 'web' }));
  await assertFails(getDoc(doc(bob, 'users/alice/devices/d1')));
  await assertFails(setDoc(doc(alice, 'users/alice/notifications/n1'), { title: 'Falso' }));
  await assertSucceeds(getDocs(collection(alice, 'users/alice/notifications')));
  await assertFails(getDocs(collection(bob, 'users/alice/notifications')));
});

const credit = (kind, postId = 'p1', referenceId = '') => ({
  kind, postId, referenceId, createdAt: serverTimestamp(),
});
test('Gamificación: fuentes verificadas, importes no editables y créditos inmutables', async () => {
  const alice = db('alice'); const bob = db('bob');
  const publish = writeBatch(alice);
  publish.set(doc(alice, 'posts/p2'), post());
  publish.set(doc(alice, 'users/alice/activity/post_p2'), credit('post', 'p2'));
  await assertSucceeds(publish.commit());
  await assertFails(setDoc(doc(bob, 'users/bob/activity/post_p2'), credit('post', 'p2')));
  await assertFails(setDoc(doc(bob, 'users/bob/activity/post_missing'), credit('post', 'missing')));
  await assertFails(setDoc(doc(alice, 'users/alice/activity/like_p1'), credit('like')));
  await assertFails(setDoc(doc(bob, 'users/bob/activity/like_p1'), credit('like')));
  const like = writeBatch(bob);
  like.update(doc(bob, 'posts/p1'), { likes: arrayUnion('bob') });
  like.set(doc(bob, 'users/bob/activity/like_p1'), credit('like'));
  await assertSucceeds(like.commit());
  await assertFails(setDoc(doc(bob, 'users/bob/activity/like_p1'), credit('like')));
  await assertFails(setDoc(doc(bob, 'users/bob/activity/forged_id'), credit('like')));
  await assertFails(setDoc(doc(bob, 'users/bob/activity/like_p2'), { ...credit('like', 'p2'), points: 1000000 }));
  await assertFails(updateDoc(doc(bob, 'users/bob/activity/like_p1'), { kind: 'post' }));
  await assertFails(deleteDoc(doc(bob, 'users/bob/activity/like_p1')));
  await assertFails(getDocs(collection(alice, 'users/bob/activity')));
  const commentBatch = writeBatch(bob);
  commentBatch.set(doc(bob, 'posts/p1/comments/rewarded'), comment('bob'));
  commentBatch.set(doc(bob, 'users/bob/activity/comment_p1'), credit('comment', 'p1', 'rewarded'));
  await assertSucceeds(commentBatch.commit());
  await assertFails(setDoc(doc(alice, 'users/alice/activity/comment_p1'), credit('comment', 'p1', 'rewarded')));
  await assertSucceeds(deleteDoc(doc(bob, 'posts/p1/comments/rewarded')));
  assert.equal((await getDocs(collection(bob, 'users/bob/activity'))).size, 2);
});

test('Chats privados: solo dos participantes, remitente real y escritura atómica del historial', async () => {
  const alice = db('alice'); const bob = db('bob'); const mallory = db('mallory');
  await assertSucceeds(getDoc(doc(alice, 'chats/c1')));
  await assertSucceeds(setDoc(doc(alice, 'chats/c1'), chatData()));
  await assertSucceeds(getDoc(doc(bob, 'chats/c1')));
  await assertSucceeds(getDocs(query(collection(bob, 'chats'), where('participants', 'array-contains', 'bob'))));
  await assertFails(getDoc(doc(mallory, 'chats/c1')));
  await assertFails(getDocs(collection(mallory, 'chats')));
  await assertFails(updateDoc(doc(alice, 'chats/c1'), { participants: ['alice', 'mallory'] }));
  await assertFails(setDoc(doc(alice, 'chats/group'), { ...chatData(), participants: ['alice', 'bob', 'mallory'] }));
  await assertFails(sendMessage(mallory, 'mallory', 'Intrusión'));
  await assertFails(sendMessage(alice, 'bob', 'Falsificado'));
  await assertFails(sendMessage(alice, 'alice', ''));
  await assertFails(sendMessage(alice, 'alice', 'a'.repeat(2001)));
  await assertFails(setDoc(doc(alice, 'chats/c1/messages/lone'), { senderId: 'alice', text: 'Sin resumen', timestamp: serverTimestamp() }));
  await assertSucceeds(sendMessage(alice, 'alice', 'Hola Bob'));
  await assertSucceeds(sendMessage(bob, 'bob', 'Hola Alice', 'm2'));
  const history = await assertSucceeds(getDocs(query(collection(bob, 'chats/c1/messages'), orderBy('timestamp'))));
  assert.deepEqual(history.docs.map(d => d.data().text), ['Hola Bob', 'Hola Alice']);
  await assertFails(getDocs(collection(mallory, 'chats/c1/messages')));
  await assertFails(updateDoc(doc(alice, 'chats/c1/messages/m1'), { text: 'Edición' }));
  await assertFails(deleteDoc(doc(alice, 'chats/c1/messages/m1')));
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
