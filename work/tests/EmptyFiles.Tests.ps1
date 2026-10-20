$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
. (Join-Path $PSScriptRoot '..\src\GameRemoval.ps1')
function Assert($value,$message){if(-not $value){throw $message}}
$fixture=Join-Path $PSScriptRoot ('empty-files-fixture-'+[Guid]::NewGuid().ToString('N'))
$downloads=Join-Path $fixture 'downloads'
$gameRoot=Join-Path $fixture 'Biblioteca\teste'
New-Item -ItemType Directory -Path $downloads,$gameRoot,(Join-Path $fixture 'Dados') -Force|Out-Null
# Reproduz o calculo antigo em pasta vazia, sob StrictMode do cliente.
$reproduced=$false
try{$old=(Get-ChildItem -LiteralPath $downloads -File|Measure-Object Length -Sum).Sum}catch{$reproduced=$true}
Assert $reproduced 'A regressao original nao foi reproduzida no PowerShell 5.1.'
Assert ((Get-CatalogFilesSize @(Get-ChildItem -LiteralPath $downloads -File)) -eq 0) 'Download vazio deveria retornar zero.'
Assert ((Get-CatalogFilesSize) -eq 0) 'Lista omitida deveria retornar zero.'
Assert ((Get-CatalogFilesSize $null) -eq 0) 'Lista nula deveria retornar zero.'
[IO.File]::WriteAllBytes((Join-Path $downloads 'primeiro.part'),[byte[]](1,2,3))
Assert ((Get-CatalogFilesSize @(Get-ChildItem -LiteralPath $downloads -File)) -eq 3) 'Primeiro arquivo nao contado.'
[IO.File]::WriteAllBytes((Join-Path $downloads 'segundo.part'),[byte[]](4,5))
Assert ((Get-CatalogFilesSize @(Get-ChildItem -LiteralPath $downloads -File)) -eq 5) 'Multiplos arquivos nao somados.'
$registry=Join-Path $fixture 'Dados\instalados.json'
[IO.File]::WriteAllText($registry,(@{teste=@{root=$gameRoot;executable='jogo.exe';version='1.0'}}|ConvertTo-Json -Depth 5))
$plan=Get-GameRemovalPlan ([pscustomobject]@{id='teste'}) $fixture
Assert ($plan.bytes -eq 0 -and $plan.saveFiles.Count -eq 0) 'Plano de remocao vazio falhou.'
Assert (Test-Path -LiteralPath $gameRoot) 'Planejamento removeu pasta.'
Write-Output 'PASS: erro Sum reproduzido; download vazio, nulo, primeiro arquivo, multiplos arquivos e plano de remocao vazio corrigidos. Nada real removido.'
