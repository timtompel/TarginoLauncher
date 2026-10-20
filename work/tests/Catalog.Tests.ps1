$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')

$root = Join-Path $PSScriptRoot 'fixture'
New-Item -ItemType Directory -Force -Path (Join-Path $root 'Jogos\Teste') | Out-Null
Set-Content -LiteralPath (Join-Path $root 'Jogos\Teste\teste.exe') -Value 'fixture' -Encoding ASCII
$game = [pscustomobject]@{ id='teste'; title='Teste'; executable='Jogos/Teste/teste.exe'; arguments=@('--nome','Acentuação e espaços'); workingDirectory='Jogos/Teste' }

$ok = Test-CatalogGame $game $root
if (-not $ok.Valid) { throw (($ok.Errors) -join '; ') }

$bad = $game | Select-Object *
$bad.executable = '..\fora.exe'
$out = Test-CatalogGame $bad $root
if ($out.Valid) { throw 'Caminho fora da raiz foi aceito' }

Write-Output 'Catalog.Tests: PASS'
