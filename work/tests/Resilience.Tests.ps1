$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
. (Join-Path $PSScriptRoot '..\src\PortablePaths.ps1')
. (Join-Path $PSScriptRoot '..\src\InstallCleanup.ps1')
$fixture=Join-Path $PSScriptRoot ('resilience-fixture-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $fixture|Out-Null
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message}}
try{
    # 1. Argumentos de linha de comando: espacos, aspas, barra final e vazio.
    Assert ((ConvertTo-WindowsArgument 'D:\') -ceq 'D:\') 'Raiz de unidade sem espacos deve passar crua.'
    Assert ((ConvertTo-WindowsArgument 'D:\Meus Jogos\') -ceq '"D:\Meus Jogos\\"') 'Barra final antes da aspa final precisa ser dobrada.'
    Assert ((ConvertTo-WindowsArgument 'a"b') -ceq '"a\"b"') 'Aspa interna precisa ser escapada.'
    Assert ((ConvertTo-WindowsArgument '') -ceq '""') 'Argumento vazio precisa de aspas.'

    # 2. JSON corrompido usa a copia .bak e sinaliza a recuperacao.
    $good=Join-Path $fixture 'good.json';$bad=Join-Path $fixture 'bad.json'
    [IO.File]::WriteAllText($bad,'{ isto nao e json');[IO.File]::WriteAllText($bad+'.bak','{"game":{"version":"1.0"}}')
    $script:JsonRecoveredFromBackup=$null
    $data=Read-CentralJsonOrBackup $bad
    Assert ($data.game.version -eq '1.0') 'Nao leu a copia de seguranca.'
    Assert ($script:JsonRecoveredFromBackup -eq $bad) 'Recuperacao nao foi sinalizada.'
    $alone=Join-Path $fixture 'alone.json';[IO.File]::WriteAllText($alone,'{ quebrado')
    $threw=$false;try{[void](Read-CentralJsonOrBackup $alone)}catch{$threw=$true}
    Assert $threw 'JSON corrompido sem .bak deve falhar.'

    # 3. Reparo de caminhos se auto-corrige a partir do .bak.
    $app=Join-Path $fixture 'app';New-Item -ItemType Directory -Force -Path (Join-Path $app 'Dados')|Out-Null
    $registry=Join-Path $app 'Dados\instalados.json'
    [IO.File]::WriteAllText($registry,'###');[IO.File]::WriteAllText($registry+'.bak','{"game":{"root":"C:\\externo-ausente","executable":"game.exe","version":"1.0"}}')
    [void](Repair-ManagedInstallPaths $app)
    Assert ((Read-CentralJson $registry).game.version -eq '1.0') 'Registro nao foi restaurado a partir do .bak.'

    # 4. Leitura tolerante de arquivo em troca.
    $status=Join-Path $fixture 'status.json';[IO.File]::WriteAllText($status,'{"state":"running"}')
    Assert ((Read-SharedJson $status).state -eq 'running') 'Leitura compartilhada falhou.'
    $lock=[IO.File]::Open($status,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try{Assert ($null -eq (Read-SharedJson $status)) 'Arquivo bloqueado deve retornar $null, nao erro.'}finally{$lock.Dispose()}

    # 5. Start-CatalogGame recusa alvos que nao sejam .exe (antes de iniciar qualquer coisa).
    $games=Join-Path $fixture 'games';New-Item -ItemType Directory -Force -Path $games|Out-Null
    [IO.File]::WriteAllText((Join-Path $games 'run.bat'),'echo nao executar')
    $entry=[pscustomobject]@{id='x';title='x';executable='run.bat';arguments=@();workingDirectory='.'}
    $threw=$false;try{[void](Start-CatalogGame $entry $games)}catch{$threw=($_.Exception.Message -match '\.exe')}
    Assert $threw 'Start-CatalogGame aceitou um alvo que nao e .exe.'

    # 6. Retencao de cache: remove somente o antigo e nao concluido.
    $cache=Join-Path $app 'Cache'
    function New-Folder([string]$Path,[string]$State,[int]$AgeDays){
        New-Item -ItemType Directory -Force -Path $Path|Out-Null
        [IO.File]::WriteAllText((Join-Path $Path 'dado.bin'),'12345')
        if($State){[IO.File]::WriteAllText((Join-Path $Path 'status.json'),('{"state":"'+$State+'"}'))}
        $old=[DateTime]::UtcNow.AddDays(-$AgeDays)
        foreach($file in Get-ChildItem -LiteralPath $Path -File){[IO.File]::SetLastWriteTimeUtc($file.FullName,$old)}
        [IO.Directory]::SetLastWriteTimeUtc($Path,$old)
    }
    $names=1..6|ForEach-Object{[Guid]::NewGuid().ToString('N')}
    New-Folder (Join-Path $cache ('AtualizacaoLauncher\'+$names[0])) '' 5
    New-Folder (Join-Path $cache ('AtualizacaoLauncher\'+$names[1])) '' 0
    New-Folder (Join-Path $cache ('Operacoes\'+$names[2])) 'error' 40
    New-Folder (Join-Path $cache ('Operacoes\'+$names[3])) 'done' 40
    New-Folder (Join-Path $cache ('Operacoes\'+$names[4])) 'error' 3
    New-Folder (Join-Path $cache ('Operacoes\'+$names[5])) '' 40
    New-Item -ItemType Directory -Force -Path (Join-Path $app 'Biblioteca\jogo')|Out-Null
    [IO.File]::WriteAllText((Join-Path $app 'Biblioteca\jogo\save.sav'),'save')
    $freed=Clear-StaleLauncherCache -AppRoot $app
    Assert ($freed -gt 0) 'Nao informou bytes liberados.'
    Assert (-not(Test-Path -LiteralPath (Join-Path $cache ('AtualizacaoLauncher\'+$names[0])))) 'Verificacao antiga do launcher nao foi removida.'
    Assert (Test-Path -LiteralPath (Join-Path $cache ('AtualizacaoLauncher\'+$names[1]))) 'Removeu verificacao recente.'
    Assert (-not(Test-Path -LiteralPath (Join-Path $cache ('Operacoes\'+$names[2])))) 'Operacao falha antiga nao foi removida.'
    Assert (Test-Path -LiteralPath (Join-Path $cache ('Operacoes\'+$names[3]))) 'Removeu operacao concluida (guarda backup de recuperacao).'
    Assert (Test-Path -LiteralPath (Join-Path $cache ('Operacoes\'+$names[4]))) 'Removeu operacao falha recente (retomada).'
    Assert (-not(Test-Path -LiteralPath (Join-Path $cache ('Operacoes\'+$names[5])))) 'Operacao abandonada sem status nao foi removida.'
    Assert ([IO.File]::ReadAllText((Join-Path $app 'Biblioteca\jogo\save.sav')) -eq 'save') 'Tocou na Biblioteca.'
    Assert ((Clear-StaleLauncherCache -AppRoot $app) -eq 0) 'Limpeza nao e idempotente.'
    'PASS: argumentos com aspas/barra final, fallback de JSON para .bak, leitura compartilhada, recusa de alvo nao .exe e retencao segura de cache.'
}finally{
    if($fixture.StartsWith($PSScriptRoot+'\') -and (Test-Path -LiteralPath $fixture)){Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue}
}
