function Get-ArquivistaMessageVersion($Metadata,[string]$Link) {
    $uri=$null
    if(-not [Uri]::TryCreate($Link,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.Host -ne 't.me'){throw 'Fonte de versao invalida.'}
    $parts=$uri.AbsolutePath.Trim('/').Split('/')
    if($parts.Length -lt 2 -or $parts[-1] -notmatch '^\d+$'){throw 'Post do jogo sem identificador.'}
    $target=$parts[-1]
    $messages=@($Metadata.messages|Where-Object {(Get-OptionalCatalogText $_ 'id') -eq $target})
    if($messages.Count -ne 1){throw 'O post exato do jogo nao foi encontrado uma unica vez. Versao nao confirmada.'}
    $text=Get-OptionalCatalogText $messages[0] 'text'
    if(-not $text){$text=Get-OptionalCatalogText $messages[0] 'message'}
    if($text -notmatch '(?im)^\s*Vers.{1,2}o\s*:?\s*\r?\n\s*([^\r\n]+)'){throw 'O post exato do jogo nao informou a versao.'}
    $line=($Matches[1] -replace '\s+',' ').Trim();$author='';$version=$line
    if($line -match '^(.*)\s[-–—]\s(.+)$'){$author=$Matches[1].Trim();$version=$Matches[2].Trim()}
    [pscustomobject]@{version=$version;author=$author;messageId=$target;source='arquivista-message'}
}

function Get-ArquivistaPostReference([string]$Link) {
    $uri=$null
    if(-not [Uri]::TryCreate($Link,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.Host -ne 't.me'){throw 'Fonte de versao invalida.'}
    $parts=$uri.AbsolutePath.Trim('/').Split('/')
    [long]$target=0
    if($parts.Length -lt 2 -or -not [long]::TryParse($parts[-1],[ref]$target) -or $target -lt 1 -or $target -gt [int]::MaxValue){throw 'Identificador do post invalido.'}
    $chat=$parts[0]
    if($chat -eq 'c'){
        if($parts.Length -lt 3 -or $parts[1] -notmatch '^\d+$'){throw 'Canal privado invalido.'}
        $chat='-100'+$parts[1]
    }
    [pscustomobject]@{messageId=[string]$target;chat=$chat;lower=[Math]::Max([long]1,$target-1);upper=$target+1}
}

function Get-ArquivistaMetadataArguments([string]$Link,[string]$Storage,[string]$Output) {
    $post=Get-ArquivistaPostReference $Link
    # Um unico limite em tdl -T id consulta ate o fim do historico.
    @('--storage',$Storage,'--reconnect-timeout','15s','chat','export','-c',$post.chat,'-T','id','-i',($post.lower.ToString()+','+$post.upper.ToString()),'--all','--with-content','-o',$Output)
}

function Compare-LauncherVersions([string]$Left,[string]$Right) {
    if([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)){return $null}
    $l=($Left.Trim() -replace '^[vV]','' -replace '[-+].*$','')
    $r=($Right.Trim() -replace '^[vV]','' -replace '[-+].*$','')
    $la=@([regex]::Matches($l,'\d+')|ForEach-Object {[int]$_.Value});$ra=@([regex]::Matches($r,'\d+')|ForEach-Object {[int]$_.Value})
    $count=[Math]::Max($la.Count,$ra.Count)
    for($i=0;$i -lt $count;$i++){ $a=if($i -lt $la.Count){$la[$i]}else{0};$b=if($i -lt $ra.Count){$ra[$i]}else{0};if($a -ne $b){return [Math]::Sign($a-$b)} }
    return 0
}

function Read-ArquivistaAcervoVersions([string]$Root) {
    $result=@{};$times=@{}
    foreach($relative in 'Arquivismo\Dados\verificacao_acervo.json','Arquivismo\Cache\verificacao_jogos.json'){
        $path=Join-Path $Root $relative
        if(-not [IO.File]::Exists($path)){continue}
        $data=Read-CentralJson $path
        if(-not $data.PSObject.Properties['Jogos']){continue}
        foreach($prop in $data.Jogos.PSObject.Properties){
            $entry=$prop.Value;$stamp=Get-OptionalCatalogText $entry 'Em'
            if(-not $stamp){$stamp=Get-OptionalCatalogText $data 'Quando'}
            $time=[datetime]::MinValue
            [void][datetime]::TryParseExact($stamp,'dd/MM/yyyy HH:mm',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$time)
            if(-not $times.ContainsKey($prop.Name) -or $time -ge $times[$prop.Name]){
                $times[$prop.Name]=$time
                $result[$prop.Name]=[pscustomobject]@{version=$(if(Get-OptionalCatalogText $entry 'Err'){''}else{Get-OptionalCatalogText $entry 'Ver'});checked=$stamp}
            }
        }
    }
    return $result
}

function Repair-ManagedGameVersions([string]$AppRoot) {
    $registry=Join-Path $AppRoot 'Dados\instalados.json';$operations=Join-Path $AppRoot 'Cache\Operacoes'
    if(-not [IO.File]::Exists($registry) -or -not [IO.Directory]::Exists($operations)){return}
    $map=Read-CentralJsonOrBackup $registry;$changed=$false
    $jobs=@(Get-ChildItem -LiteralPath $operations -Directory|Sort-Object LastWriteTime -Descending)
    foreach($prop in $map.PSObject.Properties){
        $record=$prop.Value
        if((Get-OptionalCatalogText $record 'versionSource') -eq 'arquivista-message'){continue}
        foreach($job in $jobs){
            $request=Join-Path $job.FullName 'request.json';$status=Join-Path $job.FullName 'status.json';$metadata=Join-Path $job.FullName 'metadata.json'
            if(-not [IO.File]::Exists($request) -or -not [IO.File]::Exists($status) -or -not [IO.File]::Exists($metadata)){continue}
            try{
                $req=Read-CentralJson $request;if((Get-OptionalCatalogText $req 'id') -ne $prop.Name){continue}
                $done=Read-CentralJson $status
                if($done.state -ne 'done' -or $done.id -ne $prop.Name -or $done.executable -ine $record.executable){continue}
                $expected=[IO.Path]::GetFullPath((Join-Path $AppRoot ('Biblioteca\'+$prop.Name)))
                if([IO.Path]::GetFullPath([string]$record.root) -ine $expected){continue}
                $info=Get-ArquivistaMessageVersion (Read-CentralJson $metadata) $req.link
                $record|Add-Member -NotePropertyName version -NotePropertyValue $info.version -Force
                $record|Add-Member -NotePropertyName author -NotePropertyValue $info.author -Force
                $record|Add-Member -NotePropertyName versionSource -NotePropertyValue $info.source -Force
                $record|Add-Member -NotePropertyName versionMessageId -NotePropertyValue $info.messageId -Force
                $changed=$true;break
            }catch{continue}
        }
    }
    if($changed){
        $backup=$registry+'.antes-versoes-'+[guid]::NewGuid().ToString('N')+'.bak'
        $temp=$registry+'.versions-'+[guid]::NewGuid().ToString('N')+'.tmp'
        [IO.File]::WriteAllText($temp,($map|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($true))
        [IO.File]::Replace($temp,$registry,$backup)
    }
}
