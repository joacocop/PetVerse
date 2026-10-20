const { test } = require('node:test');
const assert = require('node:assert/strict');
const { newLikers, notificationId, notice, invalidToken } = require('./notifications');
test('Detecta likes nuevos, no propios, duplicados ni remociones', () => {
  assert.deepEqual(newLikers({ likes: ['a'] }, { ownerId: 'owner', likes: ['a', 'b', 'owner', 'b'] }), ['b']);
  assert.deepEqual(newLikers({ likes: ['a', 'b'] }, { ownerId: 'owner', likes: ['b'] }), []);
});
test('IDs repetibles aíslan eventos, actores y destinatarios', () => {
  assert.equal(notificationId('event', 'a', 'b'), notificationId('event', 'a', 'b'));
  assert.notEqual(notificationId('event', 'a', 'b'), notificationId('event', 'a', 'c'));
  assert.notEqual(notificationId('event', 'a', 'b'), notificationId('event2', 'a', 'b'));
});
test('Avisos de las tres acciones, sin incluir textos privados', () => {
  for (const type of ['like', 'comment', 'message']) assert.ok(notice(type).title);
  assert.throws(() => notice('fake'));
  assert.equal(notice('message').body, 'Tenés un mensaje privado en PetVerse.');
});
test('Solo los tokens permanentemente inválidos se eliminan', () => {
  assert.equal(invalidToken('messaging/registration-token-not-registered'), true);
  assert.equal(invalidToken('messaging/server-unavailable'), false);
});
