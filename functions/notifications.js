'use strict';
const { createHash } = require('node:crypto');

/** Detecta adiciones reales, no remociones, reordenamientos ni likes propios. */
function newLikers(before, after) {
  const previous = new Set(before.likes || []);
  return [...new Set(after.likes || [])].filter(id => !previous.has(id) && id !== after.ownerId);
}
/** Identificador repetible ante reentregas del mismo evento de Firestore. */
function notificationId(eventId, actorId, targetUid) {
  return createHash('sha256').update(JSON.stringify([eventId, actorId, targetUid])).digest('hex');
}
/** No se filtra el texto de chats privados a la pantalla bloqueada. */
function notice(kind) {
  const values = {
    like: { title: '¡Nuevo me gusta!', body: 'A alguien le gustó tu publicación.' },
    comment: { title: 'Nuevo comentario', body: 'Alguien comentó tu publicación.' },
    message: { title: 'Nuevo mensaje', body: 'Tenés un mensaje privado en PetVerse.' },
  };
  if (!values[kind]) throw new Error('Tipo de notificación inválido');
  return values[kind];
}
function invalidToken(code) {
  return ['messaging/invalid-registration-token', 'messaging/registration-token-not-registered'].includes(code);
}
module.exports = { newLikers, notificationId, notice, invalidToken };
