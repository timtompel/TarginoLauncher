$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '..\src\FrontendUpdate.ps1')
function Assert($condition,[string]$message){if(-not $condition){throw $message}}
function Reject([scriptblock]$action,[string]$name){$rejected=$false;try{& $action|Out-Null}catch{$rejected=$true};Assert $rejected ('Nao bloqueou: '+$name)}
$fixture=Join-Path $PSScriptRoot ('update-fixture-'+[Guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $fixture|Out-Null
Assert (Test-FrontendNewer '0.1.0-preview.2' '0.1.0') 'Estavel igual a previa nao oferecida'
Assert (Test-FrontendNewer '0.1.0' '0.2.0') 'Nova versao nao oferecida'
Assert (-not(Test-FrontendNewer '1.0.0' '0.9.0')) 'Downgrade permitido'
Assert (-not(Test-FrontendNewer '1.0.0' '1.0.0')) 'Reinstalacao automatica permitida'
Assert (-not(Test-FrontendNewer '0.1.0' '0.2.0-preview.1')) 'Previa oferecida'
Reject {Get-FrontendVersionParts '1.2.3;cmd'} 'versao maliciosa'
$version='1.2.3';$name='TarginoLauncher-Recompilados-1.2.3-Setup.exe'
$url='https://github.com/timtompel/TarginoLauncher/releases/download/v1.2.3/'+$name
Reject {Assert-FrontendAssetUrl ($url+'?evil=1') $version $name} 'URL alterada'
Reject {Assert-FrontendAssetUrl ($url.Replace('timtompel','outro')) $version $name} 'repositorio diferente'
$release=[pscustomobject]@{draft=$false;prerelease=$false;tag_name='v1.2.3';assets=@([pscustomobject]@{name='update.json';browser_download_url='https://github.com/timtompel/TarginoLauncher/releases/download/v1.2.3/update.json'})}
Assert ((Get-FrontendStableRelease $release).version -eq $version) 'Release valida recusada'
$release.prerelease=$true;Reject {Get-FrontendStableRelease $release} 'release previa';$release.prerelease=$false
$release.draft=$true;Reject {Get-FrontendStableRelease $release} 'rascunho';$release.draft=$false
$rsa=New-Object Security.Cryptography.RSACryptoServiceProvider 3072;$rsa.PersistKeyInCsp=$false
try{
    $public=Join-Path $fixture 'public.xml';[IO.File]::WriteAllText($public,$rsa.ToXmlString($false))
    $package=Join-Path $fixture $name;[IO.File]::WriteAllBytes($package,(New-Object byte[] 2048))
    $manifest=@{schemaVersion=1;product='TarginoLauncher.Recompilados';channel='stable';version=$version;fileName=$name;url=$url;size=2048;sha256=(Get-FileHash -LiteralPath $package).Hash;notes='Teste isolado, nao publicar.'}
    $envelopePath=Join-Path $fixture 'update.json'
    function Sign-Fixture {
        $bytes=[Text.Encoding]::UTF8.GetBytes(($manifest|ConvertTo-Json -Compress))
        $envelope=@{algorithm='RSA-SHA256';payload=[Convert]::ToBase64String($bytes);signature=[Convert]::ToBase64String($rsa.SignData($bytes,'SHA256'))}
        [IO.File]::WriteAllText($envelopePath,($envelope|ConvertTo-Json))
    }
    Sign-Fixture
    $valid=Read-FrontendSignedManifest $envelopePath $public;Assert-FrontendPackage $package $valid
    $altered=[IO.File]::ReadAllText($envelopePath)|ConvertFrom-Json
    $altered.payload=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"version":"9.9.9"}'))
    [IO.File]::WriteAllText($envelopePath,($altered|ConvertTo-Json));Reject {Read-FrontendSignedManifest $envelopePath $public} 'manifesto adulterado'
    Sign-Fixture
    [IO.File]::WriteAllBytes($package,(New-Object byte[] 2049));Reject {Assert-FrontendPackage $package $valid} 'tamanho alterado'
    $bad=New-Object byte[] 2048;$bad[0]=1;[IO.File]::WriteAllBytes($package,$bad);Reject {Assert-FrontendPackage $package $valid} 'hash alterado'
    $manifest.channel='preview';Sign-Fixture;Reject {Read-FrontendSignedManifest $envelopePath $public} 'canal preview assinado'
    $manifest.channel='stable';$manifest.url=$url.Replace('timtompel','outro');Sign-Fixture;Reject {Read-FrontendSignedManifest $envelopePath $public} 'URL externa assinada'
}finally{$rsa.Dispose()}
Write-Output 'PASS: versoes, downgrade, previas, rascunhos, origem, RSA-SHA256, adulteracao de manifesto, tamanho e hash.'
Write-Output ('FIXTURE='+$fixture)
