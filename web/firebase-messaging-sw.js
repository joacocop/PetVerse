/* Configuración de CLIENTE pública, no contiene claves privadas.
 * Debe coincidir con config/firebase.local.json si se cambia de proyecto.
 * Se usa la misma versión JS que firebase_core_web 2.24.1.
 * FCM muestra automáticamente los mensajes con notification en segundo plano;
 * no agregamos showNotification para evitar duplicados.
 */
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js');
firebase.initializeApp({
  apiKey: 'AIzaSyD_mjsGyx-G7qwK6_IVaDrVJDammaJozKE',
  authDomain: 'petverse-29db2.firebaseapp.com',
  projectId: 'petverse-29db2',
  storageBucket: 'petverse-29db2.firebasestorage.app',
  messagingSenderId: '745938024957',
  appId: '1:745938024957:web:baa5b26335267cbda7c194',
});
firebase.messaging();
