'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const { defineString } = require('firebase-functions/params');
const { newLikers, notificationId, notice, invalidToken } = require('./notifications');
initializeApp();
setGlobalOptions({ maxInstances: 2, region: 'us-central1' });
const db = getFirestore();
const appUrl = defineString('APP_URL', { default: '', description: 'URL HTTPS pública de PetVerse, si existe.' });

/** Bandeja de salida durable: el cliente no puede falsificar estas notificaciones. */
async function enqueue(event, kind, actorId, targetUid, sourceId) {
  if (!targetUid || targetUid === actorId) return;
  const ref = db.doc(`users/${targetUid}/notifications/${notificationId(event.id, actorId, targetUid)}`);
  try {
    await ref.create({ ...notice(kind), kind, actorId, targetUid, sourceId,
      createdAt: FieldValue.serverTimestamp(), delivered: false });
  } catch (error) {
    if (error.code !== 6 && error.code !== 'already-exists') throw error;
  }
}

exports.onNewLike = onDocumentUpdated({ document: 'posts/{postId}', retry: true }, async event => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  await Promise.all(newLikers(before, after).map(actor =>
    enqueue(event, 'like', actor, after.ownerId, event.params.postId)));
});
exports.onNewComment = onDocumentCreated({ document: 'posts/{postId}/comments/{commentId}', retry: true }, async event => {
  const post = await db.doc(`posts/${event.params.postId}`).get();
  if (!post.exists) return;
  await enqueue(event, 'comment', event.data.data().userId, post.data().ownerId, event.params.postId);
});
exports.onNewMessage = onDocumentCreated({ document: 'chats/{chatId}/messages/{messageId}', retry: true }, async event => {
  const chat = await db.doc(`chats/${event.params.chatId}`).get();
  if (!chat.exists) return;
  const sender = event.data.data().senderId;
  const participants = chat.data().participants;
  if (!participants.includes(sender)) return;
  await Promise.all(participants.filter(uid => uid !== sender).map(uid =>
    enqueue(event, 'message', sender, uid, event.params.chatId)));
});

/** Envío exclusivamente en servidor, por lotes de hasta 500 dispositivos. */
exports.deliverNotification = onDocumentCreated({
  document: 'users/{uid}/notifications/{notificationId}', retry: true,
}, async event => {
  const current = await event.data.ref.get();
  if (current.data()?.delivered) return;
  const notification = current.data();
  const devices = await db.collection(`users/${event.params.uid}/devices`).get();
  const documents = devices.docs.filter(doc => typeof doc.data().token === 'string');
  for (let offset = 0; offset < documents.length; offset += 500) {
    const part = documents.slice(offset, offset + 500);
    const link = appUrl.value();
    const result = await getMessaging().sendEachForMulticast({
      tokens: part.map(doc => doc.data().token),
      notification: { title: notification.title, body: notification.body },
      data: { targetUid: event.params.uid, kind: notification.kind, sourceId: notification.sourceId },
      webpush: {
        notification: { tag: event.params.notificationId },
        ...(link.startsWith('https://') ? { fcmOptions: { link } } : {}),
      },
    });
    const failures = [];
    await Promise.all(result.responses.map(async (response, i) => {
      if (response.success) return;
      if (invalidToken(response.error?.code)) await part[i].ref.delete();
      else failures.push(response.error);
    }));
    if (failures.length) throw failures[0];
  }
  // Un retry posterior no reenvía un evento ya entregado. Un fallo justo entre
  // FCM y esta escritura puede repetirlo; tag estable reduce duplicados visibles.
  await current.ref.update({ delivered: true, deliveredAt: FieldValue.serverTimestamp() });
});
