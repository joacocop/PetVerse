import { createHash } from 'node:crypto';
import { readFile, writeFile, stat } from 'node:fs/promises';
import { resolve, join, relative, isAbsolute } from 'node:path';

// Solo modifica artefactos generados dentro del build indicado, nunca fuentes.
const root = resolve(process.argv[2] || 'build/web');
const source = process.argv[3] ? resolve(process.argv[3]) : null;
const entry = join(root, 'main.dart.js');
try {
  await stat(entry);
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
  throw new Error(`Falta main.dart.js en ${root}. Flutter no genero el build en esa carpeta. `
    + 'Usa scripts/publish.ps1, que indica --output explicitamente. No se publico nada.');
}
const manifest = JSON.parse(await readFile(join(root, 'manifest.json'), 'utf8'));
if (!Array.isArray(manifest.icons) || manifest.icons.length === 0) {
  throw new Error('El build contiene un manifest viejo o incompleto: faltan los iconos. '
    + 'Volvé a compilar con scripts/publish.ps1; no se publicó nada.');
}
// Detecta assets antiguos o copias parciales antes de escribir o desplegar.
if (source) {
  for (const file of ['manifest.json', 'pwa.js', 'app-sw.js', 'offline.html', 'firebase-messaging-sw.js']) {
    const expected = await readFile(join(source, file));
    const actual = await readFile(join(root, file));
    if (!expected.equals(actual)) throw new Error(`El build no coincide con web/${file}. Compilá una copia nueva antes de publicar.`);
  }
}
for (const icon of manifest.icons) {
  if (typeof icon.src !== 'string' || !icon.src) throw new Error('Icono sin ruta válida en el manifest.');
  const target = resolve(root, icon.src);
  const inside = relative(root, target);
  if (inside.startsWith('..') || isAbsolute(inside)) throw new Error('Icono fuera del build.');
  await stat(target);
  if (source && !(await readFile(join(source, icon.src))).equals(await readFile(target))) {
    throw new Error(`Icono desactualizado en el build: ${icon.src}`);
  }
}
const version = createHash('sha256');
for (const file of ['main.dart.js', 'index.html', 'app-sw.js', 'pwa.js', 'manifest.json', 'offline.html']) {
  version.update(await readFile(join(root, file)));
}
const hash = version.digest('hex').slice(0, 20);
const workerPath = join(root, 'app-sw.js');
const worker = await readFile(workerPath, 'utf8');
await writeFile(workerPath, worker.replace('__PETVERSE_BUILD__', hash));
await writeFile(join(root, 'build-info.json'), JSON.stringify({ version: hash, builtAt: new Date().toISOString() }));
console.log(`PWA verificada y versionada: ${hash}`);
