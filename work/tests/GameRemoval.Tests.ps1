$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
. (Join-Path $PSScriptRoot '..\src\GameRemoval.ps1')
function Assert($v,$m){if(-not $v){throw $m}}
function Reject([scriptblock]$action,$message){$failed=$false;try{& $action|Out-Null}catch{$failed=$true};Assert $failed $message}
$fixture=Join-Path $PSScriptRoot ('removal-fixture-'+[Guid]::NewGuid().ToString('N'))
$app=Join-Path $fixture 'Launcher';$gameRoot=Join-Path $app 'Biblioteca\teste';$unrelated=Join-Path $app 'Biblioteca\outro'
New-Item -ItemType Directory -Force -Path (Join-Path $app 'Dados'),(Join-Path $gameRoot 'save'),$unrelated|Out-Null
[IO.File]::WriteAllText((Join-Path $gameRoot 'jogo.exe'),'fixture apenas, nao executavel')
[IO.File]::WriteAllText((Join-Path $gameRoot 'save\slot.sav'),'progresso')
[IO.File]::WriteAllText((Join-Path $gameRoot 'graphics.json'),'configuracao')
[IO.File]::WriteAllText((Join-Path $unrelated 'preservar.txt'),'outro jogo')
$registry=Join-Path $app 'Dados\instalados.json'
function Write-Registry($root){[IO.File]::WriteAllText($registry,(@{teste=@{root=$root;executable='jogo.exe';version='1.0.0'};outro=@{root=$unrelated;executable='outro.exe';version='2.0.0'}}|ConvertTo-Json -Depth 6))}
Write-Registry $gameRoot
$game=[pscustomobject]@{id='teste';title='Teste'}
$plan=Get-GameRemovalPlan $game $app;Assert ($plan.saveFiles.Count -eq 2) 'Saves nao reconhecidos'
Write-Registry $fixture;Reject {Get-GameRemovalPlan $game $app} 'Aceitou pasta externa'
Write-Registry (Join-Path $app 'Biblioteca');Reject {Get-GameRemovalPlan $game $app} 'Aceitou raiz da biblioteca'
Write-Registry $gameRoot
Reject {Get-GameRemovalPlan ([pscustomobject]@{id='../teste'}) $app} 'Aceitou id com traversal'
Reject {Get-GameRemovalPlan ([pscustomobject]@{id='externo'}) $app} 'Aceitou jogo nao registrado'
# Simula cancelamento da Lixeira sem remover nenhum arquivo real.
Reject {Remove-ManagedGame $game $app $true {param($path) throw 'Cancelamento simulado'}} 'Cancelamento nao propagado'
Assert (Test-Path -LiteralPath $gameRoot) 'Cancelamento removeu jogo'
Assert ((Read-CentralJson $registry).teste.root -eq $gameRoot) 'Cancelamento alterou registro'
# Simula reciclagem por movimentacao recuperavel dentro do proprio fixture.
$recycled=Join-Path $fixture 'LixeiraSimulada'
$result=Remove-ManagedGame $game $app $true {param($path) Move-Item -LiteralPath $path -Destination $recycled}.GetNewClosure()
Assert (-not(Test-Path -LiteralPath $gameRoot)) 'Instalacao permaneceu'
Assert ([IO.File]::ReadAllText((Join-Path $result.saveBackup 'save\slot.sav')) -eq 'progresso') 'Backup de save incorreto'
Assert ([IO.File]::ReadAllText((Join-Path $result.saveBackup 'graphics.json')) -eq 'configuracao') 'Backup de configuracao incorreto'
Assert (-not (Read-CentralJson $registry).PSObject.Properties['teste']) 'Registro nao removido'
Assert ((Read-CentralJson $registry).outro.version -eq '2.0.0') 'Outro registro alterado'
Assert ([IO.File]::ReadAllText((Join-Path $unrelated 'preservar.txt')) -eq 'outro jogo') 'Outro jogo alterado'
Write-Output 'PASS: alvo exclusivo, externas bloqueadas, traversal, cancelamento, backups de saves e remocao de registro. Nenhum jogo real removido.'
