$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\FrontendUpdate.ps1')
$fixture=Join-Path $PSScriptRoot ('publisher-fixture-'+[Guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $fixture|Out-Null
$exe=Join-Path $fixture 'TarginoLauncher-Recompilados-9.8.7-Setup.exe'
Add-Type -TypeDefinition 'using System.Reflection; [assembly: AssemblyInformationalVersion("9.8.7")] public class PublisherFixture {public static void Main(){}}' -OutputAssembly $exe -OutputType ConsoleApplication
$notes=Join-Path $fixture 'notas.txt';[IO.File]::WriteAllText($notes,'Teste isolado de assinatura. NAO PUBLICAR.')
$output=Join-Path $fixture 'signed'
$testPrivate=Join-Path $fixture 'test-private.xml'
$testPublic=Join-Path $fixture 'test-public.xml'
$productionPublic=Join-Path $PSScriptRoot '..\src\UpdatePublicKey.xml'
$productionHash=(Get-FileHash -LiteralPath $productionPublic).Hash
$rsa=New-Object Security.Cryptography.RSACryptoServiceProvider 3072
$rsa.PersistKeyInCsp=$false
try{
    [IO.File]::WriteAllText($testPrivate,$rsa.ToXmlString($true))
    [IO.File]::WriteAllText($testPublic,$rsa.ToXmlString($false))
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '..\installer\Prepare-StableRelease.ps1') -TestMode -TestPrivateKeyPath $testPrivate -TestPublicKeyPath $testPublic -SetupPath $exe -Version '9.8.7' -NotesPath $notes -OutputDirectory $output
}finally{$rsa.Dispose();if(Test-Path -LiteralPath $testPrivate){Remove-Item -LiteralPath $testPrivate -Force}}
if($LASTEXITCODE){throw 'Preparacao de manifesto falhou.'}
$m=Read-FrontendSignedManifest (Join-Path $output 'update.json') $testPublic
Assert-FrontendPackage $exe $m
if((Get-FileHash -LiteralPath $productionPublic).Hash -ne $productionHash){throw 'Chave de producao alterada.'}
$rejected=$false
try{Read-FrontendSignedManifest (Join-Path $output 'update.json') $productionPublic|Out-Null}catch{$rejected=$true}
if(-not $rejected){throw 'Instalacao real aceitou assinatura de teste.'}
Write-Output 'PASS: ferramenta do publicador gerou assinatura valida para fixture, sem publicar ou executar o arquivo.'
