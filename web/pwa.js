/* Puente pequeño y sin dependencias; se carga antes de Flutter. */
(() => {
  let pending = null;
  let installed = window.matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  const subscribers = new Set();
  const state = () => installed ? 'installed' : pending ? 'available' : 'manual';
  const emit = () => subscribers.forEach(callback => callback(state()));
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault(); pending = event; emit();
  });
  window.addEventListener('appinstalled', () => { installed = true; pending = null; emit(); });
  window.matchMedia('(display-mode: standalone)').addEventListener('change', event => {
    installed = event.matches; emit();
  });
  window.petversePwaState = state;
  window.petversePwaSubscribe = callback => subscribers.add(callback);
  window.petversePwaUnsubscribe = callback => subscribers.delete(callback);
  window.petversePwaInstructions = () => {
    if (installed) return 'Ya estás usando PetVerse como aplicación instalada.';
    if (/iPad|iPhone|iPod/.test(navigator.userAgent)) {
      return 'En Safari, abrí Compartir y elegí Agregar a pantalla de inicio. Usá la dirección HTTPS publicada.';
    }
    return 'Usá el menú del navegador: Instalar PetVerse o Instalar aplicación. '
      + 'Si no aparece, abrí la dirección HTTPS publicada en Chrome o Edge. '
      + 'La disponibilidad del instalador la decide el navegador; no se puede forzar.';
  };
  window.petversePwaInstall = async () => {
    if (installed) return 'installed';
    if (!pending) return 'manual';
    const event = pending;
    pending = null;
    try {
      // Antes del primer await: conserva la activación del clic original.
      const prompted = event.prompt();
      emit();
      await prompted;
      const choice = await event.userChoice;
      return choice.outcome;
    } catch (_) { emit(); return 'error'; }
  };
  if ('serviceWorker' in navigator && window.isSecureContext) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('app-sw.js', { scope: './', updateViaCache: 'none' })
        .catch(() => { /* La app sigue disponible aunque el navegador rechace SW. */ });
    });
  }
})();
