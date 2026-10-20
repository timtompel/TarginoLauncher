function Assert-RemovalTree([string]$Path) {
    $item=Get-Item -LiteralPath $Path -Force
    for($parent=$item;$null -ne $parent;$parent=$parent.Parent){
        if(($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Links de pastas/arquivos nao sao permitidos nesta operacao.'}
    }
    $queue=New-Object Collections.Queue;$queue.Enqueue($item.FullName)
    while($queue.Count){
        foreach($entry in Get-ChildItem -LiteralPath $queue.Dequeue() -Force){
            if(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Instalacao com links: desinstalacao automatica bloqueada.'}
            if($entry.PSIsContainer){$queue.Enqueue($entry.FullName)}
        }
    }
}
. (Join-Path $PSScriptRoot 'Hashing.ps1')
function Get-GameRemovalPlan($Game,[string]$AppRoot) {
    $id=[string]$Game.id
    if($id -notmatch '^[a-z0-9][a-z0-9-]{0,159}$'){throw 'Identificador de jogo invalido.'}
    $root=[IO.Path]::GetFullPath($AppRoot).TrimEnd('\')
    $registry=Join-Path $root 'Dados\instalados.json'
    if(-not(Test-Path -LiteralPath $registry)){throw 'Somente instalacoes gerenciadas pelo nosso launcher podem ser removidas automaticamente.'}
    $map=Read-CentralJson $registry;$property=$map.PSObject.Properties[$id]
    if(-not $property){throw 'Jogo externo: nao removemos pastas do Central original ou jogos adicionados manualmente.'}
    $record=$property.Value
    $expected=[IO.Path]::GetFullPath((Join-Path $root ('Biblioteca\'+$id))).TrimEnd('\')
    $actual=[IO.Path]::GetFullPath([string]$record.root).TrimEnd('\')
    if($actual -ine $expected){throw 'Destino nao e uma pasta exclusiva gerenciada em Biblioteca. Remocao bloqueada.'}
    if(-not(Test-Path -LiteralPath $actual -PathType Container)){throw 'A pasta do jogo nao esta mais no disco.'}
    Assert-RemovalTree $actual
    $exe=Resolve-CatalogPath $actual ([string]$record.executable)
    if(-not $exe.StartsWith($actual+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Executavel fora da instalacao.'}
    $files=@(Get-ChildItem -LiteralPath $actual -Recurse -Force -File)
    $saveFiles=@($files|Where-Object {
        $relative=$_.FullName.Substring($actual.Length+1)
        $relative -match '(^|\\)(saves?|savegames|userdata|profiles|configs?|settings)(\\|$)' -or $_.Extension -in @('.sav','.srm','.eep','.mpk','.fla','.ini','.cfg','.toml','.json')
    })
    [pscustomobject]@{id=$id;root=$actual;registry=$registry;map=$map;record=$record;saveFiles=$saveFiles;bytes=(Get-CatalogFilesSize $files)}
}
function Remove-ManagedGame($Game,[string]$AppRoot,[bool]$PreserveSaves=$true,[scriptblock]$RecycleAction) {
    $plan=Get-GameRemovalPlan $Game $AppRoot
    foreach($process in Get-Process){
        $path=$null;try{$path=$process.Path}catch{}
        if($path -and $path.StartsWith($plan.root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Feche o jogo e seus programas auxiliares antes de desinstalar.'}
    }
    $operation=Join-Path ([IO.Path]::GetFullPath($AppRoot)) ('Dados\Desinstalacoes\'+$plan.id+'-'+[Guid]::NewGuid().ToString('N'))
    # Verifica ancestrais antes de criar backup fora da pasta a remover.
    $existing=[IO.DirectoryInfo]::new($operation)
    while(-not $existing.Exists){$existing=$existing.Parent}
    for($parent=$existing;$null -ne $parent;$parent=$parent.Parent){if(($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Backup com link de pasta nao permitido.'}}
    New-Item -ItemType Directory -Path $operation -Force|Out-Null
    [IO.File]::WriteAllText((Join-Path $operation 'instalados-anterior.json'),($plan.map|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($true))
    $saveBackup=''
    if($PreserveSaves){
        $saveBackup=Join-Path $operation 'Saves';New-Item -ItemType Directory -Path $saveBackup|Out-Null
        foreach($file in $plan.saveFiles){
            $relative=$file.FullName.Substring($plan.root.Length+1)
            $output=Resolve-CatalogPath $saveBackup $relative
            New-Item -ItemType Directory -Force -Path (Split-Path $output -Parent)|Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $output
            if((Get-TarginoFileSHA256 $file.FullName) -ne (Get-TarginoFileSHA256 $output)){throw 'Backup de saves nao conferiu. Nada foi removido.'}
        }
    }
    # Revalida o alvo exato imediatamente antes de enviar a Lixeira.
    [void](Get-GameRemovalPlan $Game $AppRoot)
    if($RecycleAction){& $RecycleAction $plan.root}else{
        Add-Type -AssemblyName Microsoft.VisualBasic
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($plan.root,[Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,[Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,[Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException)
    }
    if(Test-Path -LiteralPath $plan.root){throw 'A pasta continua no disco. Registro de instalacao preservado.'}
    $plan.map.PSObject.Properties.Remove($plan.id)
    $temporary=$plan.registry+'.remove-'+[Guid]::NewGuid().ToString('N')
    [IO.File]::WriteAllText($temporary,($plan.map|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($true))
    [IO.File]::Replace($temporary,$plan.registry,(Join-Path $operation 'instalados-backup.json'))
    [pscustomobject]@{id=$plan.id;saveBackup=$saveBackup;saveCount=$plan.saveFiles.Count;recovery='Lixeira do Windows'}
}
