param([Parameter(Mandatory)][string]$SetupPath)
$ErrorActionPreference='Stop'
[void][Reflection.Assembly]::LoadFile([IO.Path]::GetFullPath($SetupPath))
[Setup]::ValidateFreeSpace(4096,2048)
$blockedLowSpace=$false;try{[Setup]::ValidateFreeSpace(1024,2048)}catch{$blockedLowSpace=$true}
if(-not $blockedLowSpace){throw 'Verificacao de espaco insuficiente falhou.'}
$workspace=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$testRoot=Join-Path $workspace ('work\installation-test-'+[Guid]::NewGuid().ToString('N'))
$target=Join-Path $testRoot 'Instalacao limpa'
function Install-Fixture([string]$Folder,[int]$ExpectedExit=0){
    $process=Start-Process -FilePath $SetupPath -ArgumentList ('--test-install "'+$Folder+'"') -WindowStyle Hidden -Wait -PassThru
    if($process.ExitCode -ne $ExpectedExit){throw ('Instalador retornou '+$process.ExitCode+'; esperado '+$ExpectedExit)}
}
Install-Fixture $target
if(-not(Test-Path -LiteralPath (Join-Path $target 'TarginoLauncher-Recompilados.exe'))){throw 'Entrada executavel ausente'}
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $target 'src\CentralArquivista.ps1') -VerifyClean
if($LASTEXITCODE){throw 'Interface limpa falhou'}
foreach($folder in 'Dados','Cache','Biblioteca'){New-Item -ItemType Directory -Path (Join-Path $target $folder) -Force|Out-Null;[IO.File]::WriteAllText((Join-Path $target ($folder+'\preservar.fixture')),'conteudo pessoal simulado')}
$source=Join-Path $target 'src\Catalog.ps1'
[IO.File]::WriteAllText($source,'frontend anterior simulado')
Install-Fixture $target
foreach($folder in 'Dados','Cache','Biblioteca'){if([IO.File]::ReadAllText((Join-Path $target ($folder+'\preservar.fixture'))) -ne 'conteudo pessoal simulado'){throw ('Dados alterados: '+$folder)}}
$backups=@(Get-ChildItem -LiteralPath (Join-Path $target 'BackupsFrontend') -Recurse -File -Filter Catalog.ps1)
if(-not @($backups|Where-Object {[IO.File]::ReadAllText($_.FullName) -eq 'frontend anterior simulado'}).Count){throw 'Backup do frontend anterior nao encontrado'}
$lockFile=Join-Path $target 'Dados\launcher.lock'
$lock=[IO.File]::Open($lockFile,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try{Install-Fixture $target 1}finally{$lock.Dispose()}
# Falha no meio da copia: arquivos ja substituidos precisam ser restaurados.
[IO.File]::WriteAllText($source,'frontend para testar rollback')
$blocked=Join-Path $target 'src\Graphics.ps1'
$fileLock=[IO.File]::Open($blocked,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
try{Install-Fixture $target 1}finally{$fileLock.Dispose()}
if([IO.File]::ReadAllText($source) -ne 'frontend para testar rollback'){throw 'Rollback nao restaurou o frontend anterior'}
Install-Fixture $target
$fakeBase=Join-Path $testRoot 'BaseOriginal';New-Item -ItemType Directory -Force -Path (Join-Path $fakeBase 'Arquivismo'),(Join-Path $fakeBase 'Jogos')|Out-Null
Install-Fixture (Join-Path $fakeBase 'NaoInstalarAqui') 1
if(Test-Path -LiteralPath (Join-Path $fakeBase 'NaoInstalarAqui')){throw 'Instalou dentro do programa original'}
$owned=Get-Content -LiteralPath (Join-Path $target 'frontend.manifest')
if(@($owned|Where-Object {$_ -match '^(Dados|Cache|Biblioteca|Jogos|Logs)\\'}).Count){throw 'Pacote incluiu pastas pessoais'}
Write-Output 'PASS: instalacao limpa, inicializacao WPF, reinstalacao com preservacao, backup, rollback em falha de copia, bloqueio de app aberto e isolamento da base.'
Write-Output ('TEST_ROOT='+$testRoot)
