param([switch]$Android)
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $taskRoot
$taskFlutter=(Get-Command flutter -ErrorAction Stop).Source
$taskFlutterRoot=Split-Path -Parent (Split-Path -Parent $taskFlutter)
$taskDart=Join-Path $taskFlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
$taskSnapshot=Join-Path $taskFlutterRoot 'bin\cache\flutter_tools.snapshot'
& $taskDart $taskSnapshot pub get
if($LASTEXITCODE -ne 0){throw 'Dependency resolution failed'}
& $taskDart $taskSnapshot analyze
if($LASTEXITCODE -ne 0){throw 'Analysis failed'}
& $taskDart $taskSnapshot test --no-pub
if($LASTEXITCODE -ne 0){throw 'Tests failed'}
node --test server/server.test.mjs
if($LASTEXITCODE -ne 0){throw 'Server tests failed'}
& $taskDart $taskSnapshot build web --release --no-web-resources-cdn --no-pub
if($LASTEXITCODE -ne 0){throw 'Web build failed'}
node tools/prepare-offline.mjs
if($LASTEXITCODE -ne 0){throw 'Offline bundle failed'}
if($Android){
  & $taskDart $taskSnapshot build apk --release --no-pub
  if($LASTEXITCODE -ne 0){throw 'Android build failed'}
  New-Item -ItemType Directory -Path (Join-Path $taskRoot 'releases') -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $taskRoot 'build\app\outputs\flutter-apk\app-release.apk') -Destination (Join-Path $taskRoot 'releases\FORGE.apk') -Force
}
Write-Host 'FORGE is ready. Run Start-Forge.cmd and open http://localhost:8787'


