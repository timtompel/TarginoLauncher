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
