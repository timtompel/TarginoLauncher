$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
. (Join-Path $PSScriptRoot '..\src\PortablePaths.ps1')
$fixture=Join-Path $PSScriptRoot ('portable-fixture-'+[Guid]::NewGuid().ToString('N'))
$before=Join-Path $fixture 'Nome antigo';$after=Join-Path $fixture 'Nome novo'
New-Item -ItemType Directory -Force -Path (Join-Path $before 'Dados'),(Join-Path $before 'Biblioteca\game')|Out-Null
[IO.File]::WriteAllText((Join-Path $before 'Biblioteca\game\game.exe'),'executavel sintetico')
[IO.File]::WriteAllText((Join-Path $before 'Biblioteca\game\save.sav'),'save intacto')
$map=@{game=@{root=(Join-Path $before 'Biblioteca\game');executable='game.exe';version='1.0'};external=@{root=(Join-Path $fixture 'externo-ausente');executable='game.exe';version='1.0'}}
[IO.File]::WriteAllText((Join-Path $before 'Dados\instalados.json'),($map|ConvertTo-Json))
# Movimento restrito a fixture criada acima, nao a instalacao do usuario.
if(-not $before.StartsWith($fixture+'\') -or -not $after.StartsWith($fixture+'\')){throw 'Fixture fora do teste.'}
Move-Item -LiteralPath $before -Destination $after
if((Repair-ManagedInstallPaths $after) -ne 1){throw 'Nao reconectou exatamente um jogo.'}
$saved=Read-CentralJson (Join-Path $after 'Dados\instalados.json')
if($saved.game.root -ine (Join-Path $after 'Biblioteca\game')){throw 'Caminho nao atualizado.'}
if($saved.external.root -ne $map.external.root){throw 'Registro externo alterado.'}
if([IO.File]::ReadAllText((Join-Path $saved.game.root 'save.sav')) -ne 'save intacto'){throw 'Save alterado.'}
if((Repair-ManagedInstallPaths $after) -ne 0){throw 'Migracao nao e idempotente.'}
if(@(Get-ChildItem -LiteralPath (Join-Path $after 'Dados') -Filter '*.bak').Count -ne 1){throw 'Backup da migracao ausente.'}
Write-Output 'PASS: pasta renomeada reconecta jogo, preserva save e externo, cria backup e nao repete migracao.'
