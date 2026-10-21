$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\InstallCleanup.ps1')
$fixture=Join-Path $PSScriptRoot ('cleanup-fixture-'+[Guid]::NewGuid().ToString('N'))
$job=Join-Path $fixture ('Cache\Operacoes\'+[Guid]::NewGuid().ToString('N'))
$game=Join-Path $fixture 'Biblioteca\teste'
New-Item -ItemType Directory -Path $game,$job -Force|Out-Null
[IO.File]::WriteAllText((Join-Path $game 'game.exe'),'fixture; never execute')
[IO.File]::WriteAllText((Join-Path $game 'save.sav'),'save')
foreach($name in @('downloads','extraido','backup')){New-Item -ItemType Directory -Path (Join-Path $job $name)|Out-Null;[IO.File]::WriteAllText((Join-Path $job ($name+'\fixture.bin')),'12345')}
$status=@{state='running';id='teste';root=$game;executable='game.exe'}
$statusPath=Join-Path $job 'status.json'
[IO.File]::WriteAllText($statusPath,($status|ConvertTo-Json))
if((Clear-CompletedInstallCache $fixture $job) -ne 0){throw 'Limpou operacao ativa'}
$status.state='done';$status.executable='ausente.exe'
[IO.File]::WriteAllText($statusPath,($status|ConvertTo-Json))
$blocked=$false;try{Clear-CompletedInstallCache $fixture $job}catch{$blocked=$true};if(-not $blocked){throw 'Aceitou instalacao ausente'}
$status.executable='game.exe'
[IO.File]::WriteAllText($statusPath,($status|ConvertTo-Json))
if((Clear-CompletedInstallCache $fixture $job) -ne 10){throw 'Tamanho incorreto'}
foreach($name in @('downloads','extraido')){if(Test-Path -LiteralPath (Join-Path $job $name)){throw 'Sobrou temporario'}}
if(-not(Test-Path -LiteralPath (Join-Path $job 'backup\fixture.bin'))){throw 'Removeu backup de recuperacao'}
if(-not(Test-Path -LiteralPath (Join-Path $game 'save.sav')) -or -not(Test-Path -LiteralPath $statusPath)){throw 'Removeu arquivo protegido'}
$blocked=$false;try{Clear-CompletedInstallCache $fixture $game}catch{$blocked=$true};if(-not $blocked){throw 'Aceitou pasta de jogo'}
if((Clear-CompletedInstallCache $fixture $job) -ne 0){throw 'Limpeza nao idempotente'}
'PASS: limpa apenas temporarios de operacoes concluidas, preserva jogo/save/status e bloqueia destinos invalidos e instalacao ausente.'
