{{flutter_js}}
{{flutter_build_config}}

// El worker de la PWA se registra en pwa.js. No se activa el worker legado
// de Flutter, que compartiría el mismo scope y reemplazaría app-sw.js.
_flutter.loader.load();
