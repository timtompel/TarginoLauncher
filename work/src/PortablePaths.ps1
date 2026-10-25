function Resolve-ManagedInstallRoot([string]$AppRoot,[string]$Id,$Record){
    if($Id -cnotmatch '^[a-z0-9][a-z0-9-]{0,159}$'){throw 'Identificador de instalacao invalido.'}
    $previous=[IO.Path]::GetFullPath([string]$Record.root).TrimEnd('\')
    $expected=[IO.Path]::GetFullPath((Join-Path $AppRoot ('Biblioteca\'+$Id))).TrimEnd('\')
    if($previous -ieq $expected -or (Test-Path -LiteralPath $previous)){return $previous}
    # Reancorar apenas registros que eram filhos diretos da Biblioteca gerenciada.
    if([IO.Path]::GetFileName($previous) -cne $Id -or [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($previous)) -ine 'Biblioteca'){return $previous}
    if(-not [IO.File]::Exists((Resolve-CatalogPath $expected ([string]$Record.executable)))){return $previous}
    for($cursor=[IO.DirectoryInfo]::new($expected);$cursor;$cursor=$cursor.Parent){if($cursor.Exists -and ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Biblioteca renomeada possui link. Reconexao automatica bloqueada.'}}
    return $expected
}
function Repair-ManagedInstallPaths([string]$AppRoot){
    $path=Join-Path $AppRoot 'Dados\instalados.json'
    if(-not(Test-Path -LiteralPath $path)){return 0}
    $script:JsonRecoveredFromBackup=$null
    $map=Read-CentralJsonOrBackup $path;$changed=0
    $recovered=($script:JsonRecoveredFromBackup -eq $path)
    foreach($property in $map.PSObject.Properties){
        $root=Resolve-ManagedInstallRoot $AppRoot $property.Name $property.Value
        if($root -ine $property.Value.root){$property.Value.root=$root;$changed++}
    }
    if($changed -or $recovered){
        $temporary=$path+'.relocation-'+[Guid]::NewGuid().ToString('N')+'.tmp'
        [IO.File]::WriteAllText($temporary,($map|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($true))
        [IO.File]::Replace($temporary,$path,($path+'.antes-renomeacao-'+[Guid]::NewGuid().ToString('N')+'.bak'))
    }
    return $changed
}
