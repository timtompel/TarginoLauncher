function Read-AdditionalGames([string]$AppRoot) {
    $file=Join-Path $AppRoot 'Dados\jogos-adicionais.json'
    if(-not [IO.File]::Exists($file)){return}
    $data=Read-CentralJson $file
    if($data.schemaVersion -ne 1){throw 'Catalogo complementar com versao desconhecida.'}
    foreach($game in @($data.games)){
        if($game.id -notmatch '^local-[a-zA-Z0-9-]+$' -or -not $game.libraryRoot){throw 'Registro complementar invalido.'}
        $check=Test-CatalogGame $game $game.libraryRoot
        # Um jogo removido do disco continua visivel para permitir corrigir seu cadastro.
        $invalid=@($check.Errors|Where-Object {$_ -notmatch '^Execut.vel ausente:'})
        if($invalid.Count){throw ($invalid -join '; ')}
        Write-Output $game
    }
}

function Save-AdditionalGame($Game,[string]$AppRoot) {
    if($Game.id -notmatch '^local-[a-zA-Z0-9-]+$'){throw 'Identificador complementar invalido.'}
    if([IO.Path]::GetExtension($Game.executable) -ine '.exe'){throw 'Selecione um executavel .exe.'}
    $check=Test-CatalogGame $Game $Game.libraryRoot
    if(-not $check.Valid){throw ($check.Errors -join '; ')}
    $games=@(Read-AdditionalGames $AppRoot)
    $full=Resolve-CatalogPath $Game.libraryRoot $Game.executable
    foreach($old in $games){
        if($old.id -ne $Game.id -and (Resolve-CatalogPath $old.libraryRoot $old.executable) -ieq $full){throw 'Este executavel ja esta cadastrado no catalogo complementar.'}
    }
    $games=@($games|Where-Object id -ne $Game.id)+@($Game)
    $file=Join-Path $AppRoot 'Dados\jogos-adicionais.json'
    New-Item -ItemType Directory -Force -Path (Split-Path $file -Parent)|Out-Null
    [IO.File]::WriteAllText(($file+'.tmp'),(@{schemaVersion=1;games=$games}|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($true))
    if([IO.File]::Exists($file)){[IO.File]::Replace(($file+'.tmp'),$file,($file+'.bak'))}else{[IO.File]::Move(($file+'.tmp'),$file)}
}

function New-AdditionalGame([string]$Title,[string]$Executable,[string]$Id='') {
    $full=[IO.Path]::GetFullPath($Executable)
    if(-not $Id){$Id='local-'+[Guid]::NewGuid().ToString('N')}
    [pscustomobject]@{id=$Id;title=$Title;libraryRoot=(Split-Path $full -Parent);executable=[IO.Path]::GetFileName($full);workingDirectory='.';arguments=@();legacyArguments='';category='Adicionados por voce';platform='Windows';originalSystem='';variant='';version='';cover='';screenshot='';background='';description='';downloadLink=''}
}
