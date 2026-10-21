param([Parameter(Mandatory)][string]$Request)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Catalog.ps1')
. (Join-Path $PSScriptRoot 'GameVersions.ps1')
$req = Read-CentralJson $Request
$jobDir = Split-Path $Request -Parent
$statusFile = Join-Path $jobDir 'status.json'
function Report($state,$message,$extra=@{}) {
    $record = @{ state=$state; message=$message }
    foreach($k in $extra.Keys){$record[$k]=$extra[$k]}
    $temp = "$statusFile.tmp"
    [IO.File]::WriteAllText($temp,($record|ConvertTo-Json -Depth 6),[Text.Encoding]::UTF8)
    Move-Item -LiteralPath $temp -Destination $statusFile -Force
}
function Run-Tool($exe,$arguments,[int]$TimeoutSeconds=14400) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=$exe; $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
    $psi.WorkingDirectory=$jobDir
    $psi.Arguments=(@($arguments|ForEach-Object{'"'+([string]$_ -replace '(\\*)"','$1$1\"' -replace '(\\+)$','$1$1')+'"'}) -join ' ')
    $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
    $p=[Diagnostics.Process]::Start($psi)
    $outTask=$p.StandardOutput.ReadToEndAsync(); $errTask=$p.StandardError.ReadToEndAsync()
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while(-not $p.WaitForExit(300)) {
        if(Test-Path -LiteralPath (Join-Path $jobDir 'cancel')){$p.Kill();throw 'Operacao cancelada.'}
        if($watch.Elapsed.TotalSeconds -gt $TimeoutSeconds){$p.Kill();throw ('Tempo limite de '+$TimeoutSeconds+' segundos excedido. Verifique a conexao e tente novamente.')}
    }
    $out=$outTask.Result; $err=$errTask.Result
    if($p.ExitCode -ne 0){
        $tool=[IO.Path]::GetFileNameWithoutExtension($exe)
        $detail=($err+' '+$out) -replace '\x1b\[[0-9;]*[A-Za-z]','' -replace '[\r\n]+',' '
        $detail=$detail -replace '(?i)(token|auth_key|phone|password|session)\s*[:=]\s*\S+','$1=[oculto]'
        if($detail.Length -gt 1200){$detail=$detail.Substring($detail.Length-1200)}
        if($tool -match 'unrar' -and $p.ExitCode -eq 9){throw "Falha ao criar arquivo na extracao (UnRAR 9). Verifique caminho longo, permissao e protecao do Windows. Nao e necessario reconectar Telegram. $detail"}
        throw "$tool terminou com codigo $($p.ExitCode). $detail"
    }
    return $out
}
function Assert-NoInstallLinks([string]$Path){
    $cursor=[IO.Path]::GetFullPath($Path)
    while($cursor){
        if(Test-Path -LiteralPath $cursor){
            if((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Destino ou origem possui links. Instalacao bloqueada.'}
        }
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
}
try {
    if([string]$req.id -cnotmatch '^[a-z0-9][a-z0-9-]{0,159}$'){throw 'Identificador de jogo inseguro.'}
    if(-not [IO.Path]::IsPathRooted([string]$req.appRoot)){throw 'Raiz da biblioteca deve ser absoluta.'}
    $library=[IO.Path]::GetFullPath((Join-Path $req.appRoot 'Biblioteca'))
    $dest=[IO.Path]::GetFullPath((Join-Path $library $req.id))
    if([IO.Path]::GetDirectoryName($dest) -ine $library){throw 'Destino fora da biblioteca.'}
    Assert-NoInstallLinks $dest
    if(Test-Path -LiteralPath $dest){
        if(-not (Get-Item -LiteralPath $dest).PSIsContainer){throw 'Destino nao e uma pasta.'}
        if(@(Get-ChildItem -LiteralPath $dest -Recurse -Force | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count){throw 'Destino possui links.'}
    }
    if($req.PSObject.Properties['originalDirectory']){
        Assert-NoInstallLinks $req.originalDirectory
        if(@(Get-ChildItem -LiteralPath $req.originalDirectory -Recurse -Force | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count){throw 'Origem possui links.'}
    }
    $storage='type=file,path='+$req.session
    if(-not(Test-Path -LiteralPath $req.session)){throw 'Conecte sua conta no botao Conectar Telegram antes de baixar.'}
    $uri=[Uri]$req.link
    if($uri.Host -ne 't.me' -or $uri.Scheme -ne 'https'){throw 'A fonte precisa ser um link https://t.me/ cadastrado.'}
    $parts=$uri.AbsolutePath.Trim('/').Split('/')
    if($parts.Length -lt 2 -or $parts[-1] -notmatch '^\d+$'){throw 'O link precisa apontar para uma mensagem do Telegram.'}
    $chat=$parts[0]; $mid=[int]$parts[-1]
    if($chat -eq 'c'){ $chat='-100'+$parts[1] }
    $metaFile=Join-Path $jobDir 'metadata.json'
    Report 'running' 'Consultando somente o post do jogo no Telegram...'
    [void](Run-Tool $req.tdl (Get-ArquivistaMetadataArguments $req.link $storage $metaFile) 45)
    $meta=Read-CentralJson $metaFile
    $versionInfo=Get-ArquivistaMessageVersion $meta $req.link
    $version=$versionInfo.version;$author=$versionInfo.author
    if(-not $version){throw 'A mensagem nao informou uma versao identificavel. Nenhum jogo foi alterado.'}
    # Atualizacoes tambem baixam o pacote: a mesma versao pode conter novos mods.
    $downloads=Join-Path $jobDir 'downloads'; New-Item -ItemType Directory -Path $downloads -Force|Out-Null
    Report 'running' ("Baixando versao $version...")
    [void](Run-Tool $req.tdl @('--storage',$storage,'--reconnect-timeout','2m','-l','1','-t','2','dl','--group','--continue','--skip-same','--template','{{ filenamify .FileName }}','-d',$downloads,'-u',$req.link))
    $archives=@(Get-ChildItem -LiteralPath $downloads -File | Where-Object {$_.Name -match '\.rar$' -and $_.Name -notmatch '\.part(?!0*1\.)\d+\.rar$'})
    if($archives.Count -ne 1){throw 'Esperado um pacote RAR (ou primeira parte). Os arquivos foram mantidos para revisao.'}
    Report 'running' 'Verificando o pacote...'
    $listing=Run-Tool $req.unrar @('lb','-p-',$archives[0].FullName)
    $details=Run-Tool $req.unrar @('lt','-p-',$archives[0].FullName)
    if($details -match '(?im)^\s*(Type|Redir|Target)\s*:.*(link|junction|redirect)|symbolic link|hard link'){throw 'Pacote com links nao permitido.'}
    # Nome curto evita ultrapassar MAX_PATH nos pacotes com node_modules.
    $stage=Join-Path $jobDir 'x'; New-Item -ItemType Directory -Path $stage -Force|Out-Null
    Assert-NoInstallLinks $stage
    if(@(Get-ChildItem -LiteralPath $stage -Recurse -Force|Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count){throw 'Extracao anterior possui links. Operacao bloqueada.'}
    $archiveNames=@($listing -split '\r?\n'|Where-Object {$_})
    if(-not $archiveNames.Count){throw 'Pacote vazio. Download preservado.'}
    foreach($name in $archiveNames){
        if($name -match '(^|[\\/])\.\.([\\/]|$)|:|^[\\/]' ){throw 'Pacote com caminho inseguro.'}
        [void](Resolve-CatalogPath $stage $name)
    }
    $archivePrefix=''
    $firstRoot=($archiveNames[0] -split '[\\/]')[0]
    if($firstRoot -and @($archiveNames | Where-Object {$_ -ne $firstRoot -and -not $_.StartsWith($firstRoot+'\',[StringComparison]::OrdinalIgnoreCase)}).Count -eq 0 -and @($archiveNames | Where-Object {$_ -match '[\\/]'}).Count){$archivePrefix=$firstRoot+'\'}
    $extractArgs=@('x','-o+','-p-','-idq')
    if($archivePrefix){$extractArgs+=('-ep4'+$archivePrefix.TrimEnd('\'))}
    [void](Run-Tool $req.unrar @('t','-p-',$archives[0].FullName))
    Report 'running' 'Extraindo em pasta isolada...'
    [void](Run-Tool $req.unrar ($extractArgs+@($archives[0].FullName,($stage+'\'))))
    if(@(Get-ChildItem -LiteralPath $stage -Recurse -Force|Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count){throw 'Pacote com links de arquivos nao permitido.'}
    $expected=[IO.Path]::GetFileName($req.executable)
    $candidates=@(Get-ChildItem -LiteralPath $stage -Filter $expected -Recurse -File)
    if($candidates.Count -ne 1){throw "Nao foi encontrado um unico executavel esperado ($expected). Extracao preservada para revisao."}
    $payloadRoot=$stage
    # Mantem o layout de instalacoes antigas; novas nao repetem o titulo.
    $installPrefix=''
    if($archivePrefix -and (Test-Path -LiteralPath (Join-Path $dest $archivePrefix))){$installPrefix=$archivePrefix}
    $relativeExe=$candidates[0].FullName.Substring($payloadRoot.Length+1)
    if($installPrefix){$relativeExe=Join-Path $installPrefix $relativeExe}
    if(-not(Test-Path -LiteralPath $dest) -and $req.PSObject.Properties['originalDirectory']){
        Report 'running' 'Copiando a instalacao existente com saves e configuracoes...'
        $seed=$dest
        foreach($file in (Get-ChildItem -LiteralPath $req.originalDirectory -Recurse -File -Force)){
            if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'A instalacao existente possui links. Revise antes de atualizar.'}
            $rel=$file.FullName.Substring($req.originalDirectory.Length+1)
            $target=Resolve-CatalogPath $seed $rel
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent)|Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $target
        }
    }
    $backup=Join-Path $jobDir 'backup'
    # A biblioteca original permanece como fonte. Instalacoes novas ficam no launcher.
    Report 'running' 'Instalando e preservando configuracoes existentes...'
    $files=@(Get-ChildItem -LiteralPath $payloadRoot -Recurse -File -Force)
    $copied=New-Object Collections.Generic.List[string]
    try {
        foreach($file in $files){
            if(Test-Path -LiteralPath (Join-Path $jobDir 'cancel')){throw 'Operacao cancelada. Restaurando arquivos anteriores.'}
            $rel=$file.FullName.Substring($payloadRoot.Length+1)
            if($installPrefix){$rel=Join-Path $installPrefix $rel}
            $target=Resolve-CatalogPath $dest $rel
            Assert-NoInstallLinks $target
            if(Test-Path -LiteralPath $target){
                if($rel -match '(?i)(^|[\\/])(saves?|savegames?|userdata|profiles?|configs?|settings|mods)([\\/]|$)|\.(sav|eep|mpk|ini|cfg|toml|json)$'){continue}
                $bak=Resolve-CatalogPath $backup $rel
                New-Item -ItemType Directory -Force -Path (Split-Path $bak -Parent)|Out-Null
                Copy-Item -LiteralPath $target -Destination $bak
            }
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent)|Out-Null
            [void]$copied.Add($rel)
            Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        }
        if(-not(Test-Path -LiteralPath (Join-Path $dest $relativeExe))){throw 'Executavel nao encontrado depois da instalacao.'}
    } catch {
        foreach($rel in $copied){$target=Resolve-CatalogPath $dest $rel;$bak=Resolve-CatalogPath $backup $rel;if(Test-Path -LiteralPath $bak){Copy-Item -LiteralPath $bak -Destination $target -Force}else{Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue}}
        throw
    }
    Report 'done' 'Instalacao concluida.' @{version=$version;author=$author;root=$dest;executable=$relativeExe;id=$req.id;versionSource=$versionInfo.source;versionMessageId=$versionInfo.messageId}
} catch { Report 'error' $_.Exception.Message; exit 1 }
