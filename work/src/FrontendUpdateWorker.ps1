param([Parameter(Mandatory)][string]$Job,[Parameter(Mandatory)][ValidateSet('Check','Download')][string]$Mode,[Parameter(Mandatory)][string]$Root)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'FrontendUpdate.ps1')
function Write-State($Value){
    $temp=Join-Path $Job 'status.tmp';$path=Join-Path $Job 'status.json'
    [IO.File]::WriteAllText($temp,($Value|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($true))
    for($attempt=0;$attempt -lt 10;$attempt++){
        try{
            if([IO.File]::Exists($path)){[IO.File]::Replace($temp,$path,(Join-Path $Job 'status.previous.json'))}else{[IO.File]::Move($temp,$path)}
            return
        }catch [IO.IOException]{if($attempt -eq 9){throw};Start-Sleep -Milliseconds 50}
    }
}
try{
    $key=Join-Path $PSScriptRoot 'UpdatePublicKey.xml'
    $cancelPath=Join-Path $Job 'cancel'
    $installed=([IO.File]::ReadAllText((Join-Path $Root 'versao.json'))|ConvertFrom-Json).version
    if($Mode -eq 'Check'){
        Write-State @{state='working';message='Consultando versoes estaveis do TarginoLauncher...'}
        $releaseFile=Join-Path $Job 'release.json'
        try{Receive-FrontendFile 'https://api.github.com/repos/timtompel/TarginoLauncher/releases/latest' $releaseFile 1MB $null $cancelPath}
        catch [Net.WebException]{if($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404){Write-State @{state='none';message='Nenhuma versao estavel publicada.'};exit 0};throw}
        $release=[IO.File]::ReadAllText($releaseFile)|ConvertFrom-Json
        $candidate=Get-FrontendStableRelease $release
        if(-not(Test-FrontendNewer $installed $candidate.version)){Write-State @{state='current';message='TarginoLauncher: nenhuma estavel mais recente.'};exit 0}
        Receive-FrontendFile $candidate.manifestUrl (Join-Path $Job 'update.json') 65536 $null $cancelPath
        $m=Read-FrontendSignedManifest (Join-Path $Job 'update.json') $key
        if($m.version -cne $candidate.version){throw 'Versao da release difere do manifesto.'}
        $asset=@($release.assets|Where-Object {$_.name -ceq $m.fileName -and $_.browser_download_url -ceq $m.url -and $_.size -eq $m.size})
        if($asset.Count -ne 1){throw 'Pacote assinado nao encontrado na release.'}
        Write-State @{state='available';message=('Estavel '+$m.version+' disponivel');version=$m.version;notes=$m.notes}
    }else{
        $m=Read-FrontendSignedManifest (Join-Path $Job 'update.json') $key
        if(-not(Test-FrontendNewer $installed $m.version)){throw 'Versao antiga ou ja instalada.'}
        $download=Join-Path $Job $m.fileName
        if(Test-Path -LiteralPath $download){Move-Item -LiteralPath $download -Destination ($download+'.previous-'+[Guid]::NewGuid().ToString('N'))}
        Receive-FrontendFile $m.url $download $m.size {param($received,$total) Write-State @{state='working';message='Baixando atualizacao do launcher...';received=$received;total=$m.size}} $cancelPath
        if([IO.File]::Exists($cancelPath)){throw [OperationCanceledException]::new('Atualizacao cancelada pelo usuario.')}
        Assert-FrontendPackage $download $m
        Write-State @{state='ready';message='Pacote validado. Pronto para instalar.';package=$download;version=$m.version}
    }
}catch{
    if($_.Exception.GetBaseException() -is [OperationCanceledException]){Write-State @{state='cancelled';message='Atualizacao cancelada. Nenhum arquivo instalado foi alterado.'};exit 0}
    Write-State @{state='error';message=$_.Exception.Message};exit 1
}
