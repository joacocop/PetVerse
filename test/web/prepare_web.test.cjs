const { test } = require('node:test');
const assert = require('node:assert/strict');
const { mkdtemp, mkdir, writeFile, readFile, copyFile } = require('node:fs/promises');
const { tmpdir } = require('node:os');
const { join, resolve } = require('node:path');
const { spawnSync } = require('node:child_process');
const root = resolve(__dirname, '../..');
const script = join(root, 'scripts/prepare_web.mjs');

test('La publicación fija la salida sin depender de build-dir y comprueba main.dart.js', async () => {
  const publish = await readFile(join(root, 'scripts/publish.ps1'), 'utf8');
  assert.match(publish, /build web[^\r\n]+--output \$buildOutput/);
  assert.match(publish, /Test-Path -LiteralPath \(Join-Path \$buildOutput 'main\.dart\.js'\) -PathType Leaf/);
});

test('Un build ausente se explica antes de validar el manifest', async () => {
  const build = await mkdtemp(join(tmpdir(), 'petverse-missing-build-'));
  const result = spawnSync(process.execPath, [script, build], { encoding: 'utf8' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Falta main\.dart\.js/);
  assert.match(result.stderr, /--output/);
});

test('Un manifest antiguo se rechaza con diagnóstico claro, sin anunciar un build válido', async () => {
  const build = await mkdtemp(join(tmpdir(), 'petverse-old-build-'));
  await writeFile(join(build, 'main.dart.js'), '// fixture');
  await writeFile(join(build, 'manifest.json'), JSON.stringify({ name: 'PetVerse' }));
  const result = spawnSync(process.execPath, [script, build], { encoding: 'utf8' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /manifest viejo o incompleto/);
  assert.doesNotMatch(result.stderr, /is not iterable/);
});

async function freshBuild() {
  const build = await mkdtemp(join(tmpdir(), 'petverse-fresh-build-'));
  const source = join(root, 'web');
  await mkdir(join(build, 'icons'));
  for (const file of ['manifest.json','pwa.js','app-sw.js','offline.html','firebase-messaging-sw.js']) {
    await copyFile(join(source, file), join(build, file));
  }
  const manifest = JSON.parse(await readFile(join(source, 'manifest.json'), 'utf8'));
  for (const icon of manifest.icons) await copyFile(join(source, icon.src), join(build, icon.src));
  await writeFile(join(build, 'main.dart.js'), '// fixture');
  await writeFile(join(build, 'index.html'), '<html></html>');
  return { build, source };
}

test('El build nuevo coincide con fuentes e iconos antes de versionar la PWA', async () => {
  const { build, source } = await freshBuild();
  const result = spawnSync(process.execPath, [script, build, source], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  const info = JSON.parse(await readFile(join(build, 'build-info.json'), 'utf8'));
  assert.match(info.version, /^[a-f0-9]{20}$/);
  assert.ok((await readFile(join(build, 'app-sw.js'), 'utf8')).includes(info.version));
});

test('Una copia parcial de assets se rechaza antes de publicar', async () => {
  const { build, source } = await freshBuild();
  await writeFile(join(build, 'pwa.js'), '// asset viejo');
  const result = spawnSync(process.execPath, [script, build, source], { encoding: 'utf8' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /no coincide con web\/pwa.js/);
});
