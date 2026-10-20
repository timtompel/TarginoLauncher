param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Output)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Catalog.ps1')
. (Join-Path $PSScriptRoot 'BaseUpdate.ps1')
$version=''
try{
    $context=Get-BaseUpdateContext $Root;$version=$context.version
    if(-not $context.url){$result=@{state='disabled';version=$version;message='A base nao possui endereco de atualizacao configurado.'}}
    else{
        $url=$null
        if(-not [Uri]::TryCreate($context.url,[UriKind]::Absolute,[ref]$url) -or $url.Scheme -ne 'https' -or $url.UserInfo){throw 'Endereco de atualizacao da base invalido.'}
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        $request=[Net.HttpWebRequest]::Create($url)
        $request.Method='HEAD';$request.Timeout=15000;$request.ReadWriteTimeout=15000;$request.MaximumAutomaticRedirections=5
        $request.UserAgent='CentralArquivistaLauncher/0.1';$request.CachePolicy=[Net.Cache.RequestCachePolicy]::new([Net.Cache.RequestCacheLevel]::NoCacheNoStore)
        $response=$request.GetResponse()
        try{
            if($response.ResponseUri.Scheme -ne 'https'){throw 'Redirecionamento fora de HTTPS.'}
            $remote=([string]$response.Headers['ETag']).Trim()
            if(-not $remote){$modified=([string]$response.Headers['Last-Modified']).Trim();if($modified -and $response.ContentLength -ge 0){$remote=$modified+'|'+$response.ContentLength}}
        }finally{$response.Close()}
        $state=Compare-BasePackage $context.marker $remote
        $message=switch($state){current{'Pacote da base confere com o ultimo aplicado.'}changed{'Atualizacao da base detectada. Use Configuracoes > Atualizar Central original.'}default{'Nao ha identificador suficiente para confirmar atualizacao.'}}
        $result=@{state=$state;version=$version;message=$message;checkedUtc=[DateTime]::UtcNow.ToString('o')}
    }
}catch{$result=@{state='error';version=$version;message='Nao foi possivel verificar a base agora. A biblioteca continua disponivel.'}}
$temp=$Output+'.tmp'
[IO.File]::WriteAllText($temp,($result|ConvertTo-Json),[Text.UTF8Encoding]::new($true))
Move-Item -LiteralPath $temp -Destination $Output -Force
