param(
  [switch]$Deploy,
  [string]$ProjectId = 'petverse-29db2',
  [string]$Flutter = 'flutter',
  [string]$Node = 'node',
  [string]$Firebase = 'firebase'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterCommand = (Get-Command $Flutter -ErrorAction Stop).Source
$nodeCommand = (Get-Command $Node -ErrorAction Stop).Source
$firebaseCommand = Get-Command $Firebase -ErrorAction SilentlyContinue
$localCli = Join-Path $projectRoot 'test/firestore/node_modules/firebase-tools/lib/bin/firebase.js'
Push-Location -LiteralPath $projectRoot
try {
  if (-not (Test-Path -LiteralPath 'config/firebase.local.json')) {
    throw 'Falta config/firebase.local.json; no se publica una demo por accidente.'
  }
  $clientConfig = Get-Content -LiteralPath 'config/firebase.local.json' -Raw | ConvertFrom-Json
  if ($clientConfig.FIREBASE_PROJECT_ID -ne $ProjectId) {
    throw 'El proyecto del cliente no coincide con el destino del despliegue.'
  }
  # OneDrive puede dejar build/web antiguo aunque exista main.dart.js.
  # Cada ejecucion compila en una copia nueva; nunca reutiliza ese build.
  $stagingRoot = Join-Path ([IO.Path]::GetTempPath()) ('PetVerse-publish-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $stagingRoot | Out-Null
  & robocopy $projectRoot $stagingRoot /E /XD .git .dart_tool build node_modules .firebase /XF *.log /NFL /NDL /NJH /NJS /NP
  if ($LASTEXITCODE -ge 8) { throw 'No se pudo preparar la copia temporal. No se publico nada.' }
  Set-Location -LiteralPath $stagingRoot
  Write-Output "Compilando una copia nueva fuera de OneDrive: $stagingRoot"
  & $flutterCommand pub get
  if ($LASTEXITCODE -ne 0) { throw 'Fallo la preparacion de dependencias. No se publico nada.' }
  # --output evita depender de un build-dir personalizado de Flutter.
  $buildOutput = Join-Path $stagingRoot 'build/web'
  & $flutterCommand build web --release --dart-define-from-file=config/firebase.local.json --output $buildOutput
  if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion web. No se publico nada.' }
  if (-not (Test-Path -LiteralPath (Join-Path $buildOutput 'main.dart.js') -PathType Leaf)) {
    throw "Flutter no genero main.dart.js en $buildOutput. No se publico nada."
  }
  & $nodeCommand scripts/prepare_web.mjs $buildOutput web
  if ($LASTEXITCODE -ne 0) { throw 'Fallo la validacion PWA. No se publico nada.' }
  if ($Deploy) {
    # Solo Hosting: no Functions, Storage, facturación, reglas ni otros servicios.
    if ($null -ne $firebaseCommand) {
      & $firebaseCommand.Source deploy --project $ProjectId --only hosting
    } elseif (Test-Path -LiteralPath $localCli) {
      & $nodeCommand $localCli deploy --project $ProjectId --only hosting
    } else { throw 'Falta Firebase CLI. Instalalo o ejecuta npm ci en test/firestore.' }
    if ($LASTEXITCODE -ne 0) { throw 'No se confirmo el despliegue.' }
  } else { Write-Output "Build preparado en $stagingRoot\build\web. Usa -Deploy para publicar solo Hosting." }
} finally { Pop-Location }
