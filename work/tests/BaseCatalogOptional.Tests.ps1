$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
$minimal=[pscustomobject]@{Id='teste';Name='Teste (N64)';Exe='Jogos\Teste\teste.exe'}
$game=Convert-BaseCatalogEntry $minimal
if($game.version -ne '' -or $game.description -ne '' -or $game.legacyArguments -ne '' -or $game.arguments.Count -ne 0){throw 'Campos opcionais nao receberam valores seguros.'}
if($game.executable -ne 'Jogos/Teste/teste.exe'){throw 'Caminho incorreto.'}
if((Get-OptionalCatalogText $minimal 'Shot') -ne ''){throw 'Captura ausente nao aceita.'}
$complete=[pscustomobject]@{Id='completo';Name='Completo';Exe='jogo.exe';Version='1.2.3';Desc='Texto';Args='-a'}
$game=Convert-BaseCatalogEntry $complete
if($game.version -ne '1.2.3' -or $game.description -ne 'Texto' -or $game.workingDirectory -ne '.'){throw 'Campos existentes nao preservados.'}
Write-Output 'PASS: importacao com campos opcionais ausentes e existentes.'
