function Clear-CompletedInstallCache {
    param([Parameter(Mandatory)][string]$AppRoot,[Parameter(Mandatory)][string]$Job)
    $root=[IO.Path]::GetFullPath($AppRoot).TrimEnd('\')
    $operations=[IO.Path]::GetFullPath((Join-Path $root 'Cache\Operacoes'))
    $jobPath=[IO.Path]::GetFullPath($Job).TrimEnd('\')
    if([IO.Path]::GetDirectoryName($jobPath) -ine $operations -or [IO.Path]::GetFileName($jobPath) -cnotmatch '^[a-f0-9]{32}$'){throw 'Cache fora da pasta de operacoes.'}
    # Nao atravessar junctions ou links, inclusive em ancestrais.
    $cursor=$jobPath
    while($cursor){
        if((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Cache com link bloqueado.'}
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
    $status=Get-Content -LiteralPath (Join-Path $jobPath 'status.json') -Raw | ConvertFrom-Json
    if($status.state -ne 'done'){return [long]0}
    if([string]$status.id -cnotmatch '^[a-z0-9][a-z0-9-]{0,159}$'){throw 'Jogo invalido no cache.'}
    $destination=[IO.Path]::GetFullPath((Join-Path (Join-Path $root 'Biblioteca') $status.id))
    $recorded=[IO.Path]::GetFullPath([string]$status.root).TrimEnd('\')
    if($recorded -ine $destination){
        # Historico de antes da renomeacao da pasta: confirmar tambem o request.
        $request=Get-Content -LiteralPath (Join-Path $jobPath 'request.json') -Raw | ConvertFrom-Json
        $oldExpected=[IO.Path]::GetFullPath((Join-Path (Join-Path $request.appRoot 'Biblioteca') $status.id))
        if($recorded -ine $oldExpected -or (Test-Path -LiteralPath $recorded)){throw 'Instalacao fora da biblioteca.'}
    }
    $exe=[IO.Path]::GetFullPath((Join-Path $destination ([string]$status.executable)))
    if(-not $exe.StartsWith($destination+'\',[StringComparison]::OrdinalIgnoreCase) -or -not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'Instalacao nao confirmada; cache preservado.'}
    $targets=@()
    [long]$bytes=0
    foreach($name in @('downloads','extraido','x')){
        $target=Join-Path $jobPath $name
        if(-not(Test-Path -LiteralPath $target)){continue}
        $items=@(Get-Item -LiteralPath $target -Force)+@(Get-ChildItem -LiteralPath $target -Recurse -Force)
        if(@($items | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count){throw 'Cache com links preservado.'}
        foreach($item in $items){if(-not $item.PSIsContainer){$bytes+=$item.Length}}
        $targets+= $target
    }
    # Somente download e extracao; backups de recuperacao, status e request ficam.
    foreach($target in $targets){Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop}
    return $bytes
}

function Test-TreeHasLinks([string]$Path) {
    $item=Get-Item -LiteralPath $Path -Force
    if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){return $true}
    if(-not $item.PSIsContainer){return $false}
    foreach($child in Get-ChildItem -LiteralPath $Path -Recurse -Force){if($child.Attributes -band [IO.FileAttributes]::ReparsePoint){return $true}}
    return $false
}
# Politica de retencao do Cache. Nunca toca em Biblioteca, Dados, jogos concluidos ou backups de recuperacao.
#  - AtualizacaoLauncher: pastas de verificacao/download do proprio launcher (> 2 dias)
#  - AtualizacaoBase: respostas de verificacao da base (> 2 dias)
#  - Operacoes: instalacoes de jogo NAO concluidas (erro/cancelada/abandonada) sem uso ha > 30 dias
function Clear-StaleLauncherCache {
    param([Parameter(Mandatory)][string]$AppRoot,[int]$LauncherDays=2,[int]$AbandonedOperationDays=30,[datetime]$Now=[datetime]::UtcNow)
    $root=[IO.Path]::GetFullPath($AppRoot).TrimEnd('\')
    $cache=Join-Path $root 'Cache'
    [long]$freed=0
    if(-not(Test-Path -LiteralPath $cache -PathType Container)){return $freed}
    if((Get-Item -LiteralPath $cache -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){return $freed}
    $remove={
        param([string]$Target)
        if(Test-TreeHasLinks $Target){return [long]0}
        [long]$size=0
        $item=Get-Item -LiteralPath $Target -Force
        $files=if($item.PSIsContainer){@(Get-ChildItem -LiteralPath $Target -Recurse -Force -File -ErrorAction SilentlyContinue)}else{@($item)}
        foreach($f in $files){$size+=$f.Length}
        try{Remove-Item -LiteralPath $Target -Recurse -Force -ErrorAction Stop;return $size}catch{return [long]0}
    }
    foreach($name in 'AtualizacaoLauncher','AtualizacaoBase'){
        $folder=Join-Path $cache $name
        if(-not(Test-Path -LiteralPath $folder -PathType Container)){continue}
        if((Get-Item -LiteralPath $folder -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){continue}
        $limit=$Now.AddDays(-$LauncherDays)
        foreach($entry in Get-ChildItem -LiteralPath $folder -Force){
            if($entry.LastWriteTimeUtc -lt $limit -and ($entry.Name -match '^[a-f0-9]{32}(\.json(\.tmp)?)?$')){$freed+=(& $remove $entry.FullName)}
        }
    }
    $operations=Join-Path $cache 'Operacoes'
    if(Test-Path -LiteralPath $operations -PathType Container){
        if(-not((Get-Item -LiteralPath $operations -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){
            $limit=$Now.AddDays(-$AbandonedOperationDays)
            foreach($job in Get-ChildItem -LiteralPath $operations -Directory -Force){
                if($job.Name -cnotmatch '^[a-f0-9]{32}$'){continue}
                $statusPath=Join-Path $job.FullName 'status.json'
                $last=$job.LastWriteTimeUtc
                $state=''
                if([IO.File]::Exists($statusPath)){
                    $statusFile=Get-Item -LiteralPath $statusPath -Force
                    if($statusFile.LastWriteTimeUtc -gt $last){$last=$statusFile.LastWriteTimeUtc}
                    try{$state=[string]((Get-Content -LiteralPath $statusPath -Raw|ConvertFrom-Json).state)}catch{$state=''}
                }
                # Concluidas guardam backup de recuperacao: nunca removidas aqui.
                if($state -eq 'done'){continue}
                if($last -lt $limit){$freed+=(& $remove $job.FullName)}
            }
        }
    }
    return $freed
}
