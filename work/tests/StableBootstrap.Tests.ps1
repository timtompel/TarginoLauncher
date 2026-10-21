$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
function Assert($condition,$message){if(-not $condition){throw $message}}
function Reject([scriptblock]$action,$message){$blocked=$false;try{& $action|Out-Null}catch{$blocked=$true};Assert $blocked $message}
$fixture=Join-Path $PSScriptRoot ('bootstrap-fixture-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture|Out-Null
$rsa=New-Object Security.Cryptography.RSACryptoServiceProvider 3072;$rsa.PersistKeyInCsp=$false
try{
    $key=Join-Path $fixture 'public.xml';[IO.File]::WriteAllText($key,$rsa.ToXmlString($false))
    & (Join-Path $PSScriptRoot '..\installer\Build-StableBootstrap.ps1') -Version '1.2.3' -TestMode -TestPublicKeyPath $key -OutputDirectory $fixture
    $exe=Join-Path $fixture 'Bootstrap-Fixture-NAO-PUBLICAR.exe'
    [void][Reflection.Assembly]::LoadFile($exe)
    $packagePath=Join-Path $fixture 'pacote.fixture';[IO.File]::WriteAllBytes($packagePath,(New-Object byte[] 2048))
    $hashAlgorithm=[Security.Cryptography.SHA256]::Create();try{$hash=[BitConverter]::ToString($hashAlgorithm.ComputeHash([IO.File]::ReadAllBytes($packagePath))).Replace('-','')}finally{$hashAlgorithm.Dispose()}
    $manifest=@{schemaVersion=1;product='TarginoLauncher.Recompilados';channel='stable';version='1.2.3';fileName='TarginoLauncher-Recompilados-1.2.3-Setup.exe';url='https://github.com/timtompel/TarginoLauncher/releases/download/v1.2.3/TarginoLauncher-Recompilados-1.2.3-Setup.exe';size=2048;sha256=$hash}
    function Envelope($data){$bytes=[Text.Encoding]::UTF8.GetBytes(($data|ConvertTo-Json -Compress));@{algorithm='RSA-SHA256';payload=[Convert]::ToBase64String($bytes);signature=[Convert]::ToBase64String($rsa.SignData($bytes,'SHA256'))}|ConvertTo-Json -Compress}
    $signed=Envelope $manifest;$package=[StableBootstrapSecurity]::ReadManifest($signed)
    [StableBootstrapSecurity]::ValidatePackage($packagePath,$package)
    $modified=New-Object byte[] 2048;$modified[0]=1;[IO.File]::WriteAllBytes($packagePath,$modified)
    Reject {[StableBootstrapSecurity]::ValidatePackage($packagePath,$package)} 'Aceitou adulteracao do mesmo tamanho'
    [IO.File]::WriteAllBytes($packagePath,(New-Object byte[] 2049))
    Reject {[StableBootstrapSecurity]::ValidatePackage($packagePath,$package)} 'Aceitou tamanho errado'
    $tampered=$signed|ConvertFrom-Json;$tampered.payload=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{}'))
    Reject {[StableBootstrapSecurity]::ReadManifest(($tampered|ConvertTo-Json -Compress))} 'Aceitou assinatura adulterada'
    $manifest.url='https://example.com/arquivo.exe';Reject {[StableBootstrapSecurity]::ReadManifest((Envelope $manifest))} 'Aceitou origem externa assinada'
    $manifest.url='https://github.com/timtompel/TarginoLauncher/releases/download/v1.2.3/TarginoLauncher-Recompilados-1.2.3-Setup.exe';$manifest.channel='preview'
    Reject {[StableBootstrapSecurity]::ReadManifest((Envelope $manifest))} 'Aceitou canal preview'
    Assert ([StableBootstrapSecurity]::ReleaseVersion('{"draft":false,"prerelease":false,"tag_name":"v1.2.3"}') -eq '1.2.3') 'Recusou release estavel'
    Reject {[StableBootstrapSecurity]::ReleaseVersion('{"draft":false,"prerelease":true,"tag_name":"v1.2.3"}')} 'Aceitou previa'
    Reject {[StableBootstrapSecurity]::ResolveLatest([Func[bool]]{return $true})} 'Cancelamento anterior a rede falhou'
    $exclusive=[IO.File]::Open($packagePath,'Open','ReadWrite','None');$exclusive.Dispose()
}finally{$rsa.Dispose()}
Write-Output 'PASS: bootstrap verifica RSA3072, origem, hash/tamanho, recusa previas e adulteracao, respeita cancelamento e libera arquivos. Sem instalar programa.'
