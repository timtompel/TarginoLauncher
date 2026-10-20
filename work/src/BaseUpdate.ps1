function Get-BaseUpdateContext([string]$Root){
    $scriptPath=Join-Path $Root 'Arquivismo\Launcher.ps1'
    if(-not [IO.File]::Exists($scriptPath)){throw 'Instalacao base nao encontrada.'}
    $source=[IO.File]::ReadAllText($scriptPath)
    $versionMatch=[regex]::Match($source,'(?m)^\s*\$AppVer\s*=\s*[''"]([^''"]+)[''"]')
    $version=if($versionMatch.Success){$versionMatch.Groups[1].Value}else{'nao identificada'}
    $layout=Read-CentralJson (Join-Path $Root 'Arquivismo\Dados\layout.json')
    $url=if($layout.PSObject.Properties['UpdUrl']){[string]$layout.UpdUrl}else{''}
    $marker=''
    $state=Join-Path $Root 'Arquivismo\Dados\atualizacao.json'
    if([IO.File]::Exists($state)){$saved=Read-CentralJson $state;if($saved.PSObject.Properties['ETag']){$marker=[string]$saved.ETag}}
    [pscustomobject]@{version=$version;url=$url;marker=$marker}
}
function Compare-BasePackage([string]$Installed,[string]$Remote){
    if([string]::IsNullOrWhiteSpace($Installed) -or [string]::IsNullOrWhiteSpace($Remote)){return 'unknown'}
    if($Installed -ceq $Remote){return 'current'}
    return 'changed'
}
