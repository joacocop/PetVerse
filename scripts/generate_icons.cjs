/* Rasteriza el icono vectorial del proyecto, sin servicios externos.
 * Requiere sharp: disponible en el runtime de documentos de Codex, o instalar
 * en una carpeta de herramientas y pasar PETVERSE_NODE_MODULES a ese node_modules.
 */
const { createRequire } = require('node:module');
const { resolve, join } = require('node:path');
const { readFileSync } = require('node:fs');
const req = process.env.PETVERSE_NODE_MODULES
  ? createRequire(join(resolve(process.env.PETVERSE_NODE_MODULES), '_resolve.cjs')) : require;
const sharp = req('sharp');
const root = resolve(__dirname, '..');
const source = readFileSync(join(root, 'web/icons/paw.svg'));
(async () => {
  for (const [name, size] of [['icon-192.png',192],['icon-512.png',512],
    ['maskable-192.png',192],['maskable-512.png',512],['apple-touch-icon.png',180]]) {
    // El dibujo permanece dentro del círculo seguro de iconos maskable.
    let pipeline = sharp(source).resize(size, size);
    if (name.startsWith('maskable')) {
      pipeline = sharp({ create: { width: size, height: size, channels: 4,
        background: '#FF6B35' } }).composite([{ input: await sharp(source).resize(size, size).png().toBuffer() }]);
    }
    await pipeline.png().toFile(join(root, 'web/icons', name));
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
