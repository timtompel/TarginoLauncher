Set-StrictMode -Version Latest

function Get-GraphicsSupport {
    param($Game,[string]$Root)
    $result=[pscustomobject]@{Supported=$false;Options=@();ConfigPath='';Current='';Message='Troca de renderizador ainda nao verificada para este port.'}
    $leaf=[IO.Path]::GetFileName($Game.executable)
    if($leaf -eq 'ge007.x86_64.exe'){$result.Message='Este port usa OpenGL 3.0. Troca para Vulkan ou software nao confirmada.';return $result}
    if($leaf -match '^pd\.(?:pal\.|jpn\.)?x86_64\.exe$'){$result.Message='Port com renderizacao OpenGL; troca de API pelo launcher nao confirmada.';return $result}
    if($leaf -notin @('BanjoRecompiled.exe','beetle-adventure-racing-recomp.exe','BodyHarvestRecompiled.exe','Zelda64Recompiled.exe')){return $result}
    try{
        $exe=Resolve-CatalogPath $Root $Game.executable
        if(-not [IO.File]::Exists($exe)){$result.Message='Instale o jogo antes de configurar o renderizador.';return $result}
        $dir=Split-Path $exe -Parent
        if(-not [IO.File]::Exists((Join-Path $dir 'portable.txt'))){$result.Message='Modo portatil nao confirmado; local da configuracao precisa ser verificado.';return $result}
        $config=Join-Path $dir 'graphics.json'
        $obj=Read-CentralJson $config
        if(-not $obj.PSObject.Properties['api_option'] -or $obj.api_option -notin @('Auto','D3D12','Vulkan')){throw 'Campo api_option ausente ou desconhecido.'}
        $result.Supported=$true;$result.Options=@('Keep','Auto','D3D12','Vulkan');$result.ConfigPath=$config;$result.Current=[string]$obj.api_option
        $result.Message='Configuracao do port RT64. OpenGL e software nao estao disponiveis neste perfil. A GPU e o driver precisam suportar a API escolhida.'
    }catch{$result.Message='Nao foi possivel validar graphics.json: '+$_.Exception.Message}
    return $result
}

function Read-GraphicsPreferences([string]$AppRoot) {
    $path=Join-Path $AppRoot 'Dados\renderizadores.json'
    $map=@{}
    if(Test-Path -LiteralPath $path){$obj=Read-CentralJson $path;foreach($p in $obj.PSObject.Properties){$map[$p.Name]=[string]$p.Value}}
    return $map
}

function Save-GraphicsPreference($Game,[string]$Root,[string]$AppRoot,[string]$Choice) {
    $support=Get-GraphicsSupport $Game $Root
    if(-not $support.Supported -or $Choice -notin $support.Options){throw 'Renderizador nao suportado por este perfil.'}
    if($Game.id -notmatch '^[a-zA-Z0-9._-]+$'){throw 'Identificador invalido.'}
    $map=Read-GraphicsPreferences $AppRoot
    $map[$Game.id]=$Choice
    $path=Join-Path $AppRoot 'Dados\renderizadores.json'
    New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force|Out-Null
    [IO.File]::WriteAllText(($path+'.tmp'),($map|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    if([IO.File]::Exists($path)){[IO.File]::Replace(($path+'.tmp'),$path,($path+'.bak'))}else{[IO.File]::Move(($path+'.tmp'),$path)}
}

function Apply-GraphicsPreference($Game,[string]$Root,[string]$AppRoot) {
    $map=Read-GraphicsPreferences $AppRoot
    if(-not $map.ContainsKey($Game.id) -or $map[$Game.id] -eq 'Keep'){return}
    $choice=$map[$Game.id]
    $support=Get-GraphicsSupport $Game $Root
    if(-not $support.Supported -or $choice -notin $support.Options){throw 'O perfil grafico salvo nao corresponde mais a esta instalacao. Revise Renderizador.'}
    if($support.Current -eq $choice){return}
    $exe=Resolve-CatalogPath $Root $Game.executable
    foreach($process in [Diagnostics.Process]::GetProcesses()){
        $processPath=$null
        try{$processPath=$process.MainModule.FileName}catch { }
        finally{$process.Dispose()}
        if($processPath -ieq $exe){throw 'Feche o jogo antes de alterar o renderizador.'}
    }
    $path=$support.ConfigPath
    $node=Get-Item -LiteralPath $path -Force
    while($node){
        if($node.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Configuracao em caminho com link nao permitida.'}
        if($node.FullName.TrimEnd('\') -ieq ([IO.Path]::GetFullPath($Root)).TrimEnd('\')){break}
        $node=if($node -is [IO.FileInfo]){$node.Directory}else{$node.Parent}
    }
    $raw=[IO.File]::ReadAllText($path,[Text.Encoding]::UTF8)
    $rx=[regex]'("api_option"\s*:\s*")(Auto|D3D12|Vulkan)(")'
    if($rx.Matches($raw).Count -ne 1){throw 'Configuracao ambigua. Nenhum arquivo foi alterado.'}
    $replacement=$rx.Replace($raw,('${1}'+$choice+'${3}'),1)
    [void]($replacement|ConvertFrom-Json)
    $backupDir=Join-Path $AppRoot ('Dados\BackupsGraficos\'+$Game.id)
    New-Item -ItemType Directory -Force -Path $backupDir|Out-Null
    Copy-Item -LiteralPath $path -Destination (Join-Path $backupDir ([Guid]::NewGuid().ToString('N')+'.json'))
    $bytes=[IO.File]::ReadAllBytes($path)
    $bom=$bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191
    $temp=$path+'.central-'+[Guid]::NewGuid().ToString('N')+'.tmp'
    [IO.File]::WriteAllText($temp,$replacement,[Text.UTF8Encoding]::new($bom))
    [IO.File]::Replace($temp,$path,[System.Management.Automation.Language.NullString]::Value)
}
