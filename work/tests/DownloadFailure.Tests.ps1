$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\FrontendUpdate.ps1')
$fixture=Join-Path $PSScriptRoot ('network-fixture-'+[Guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $fixture|Out-Null
$code=@'
using System;using System.IO;using System.Net;using System.Net.Cache;
public class TestRequestCreator:IWebRequestCreate{public WebRequest Create(Uri uri){return new TestRequest(uri);}}
public class TestRequest:WebRequest{
 Uri uri;public TestRequest(Uri value){uri=value;}public string UserAgent{get;set;}public int ReadWriteTimeout{get;set;}public override int Timeout{get;set;}public override RequestCachePolicy CachePolicy{get;set;}
 public override WebResponse GetResponse(){if(uri.AbsolutePath.EndsWith("timeout"))throw new WebException("Timeout simulado",WebExceptionStatus.Timeout);return new TestResponse(uri);}
}
public class TestResponse:WebResponse{
 Uri uri;public TestResponse(Uri value){uri=value;}public override Uri ResponseUri{get{return uri;}}public override long ContentLength{get{return uri.AbsolutePath.EndsWith("oversize")?2048:32;}set{}}
 public override Stream GetResponseStream(){return uri.AbsolutePath.EndsWith("interrupt")?(Stream)new BrokenStream():new MemoryStream(new byte[32]);}
}
public class BrokenStream:MemoryStream{
 bool first=true;public BrokenStream():base(new byte[32]){}public override int Read(byte[] b,int o,int c){if(!first)throw new IOException("Conexao interrompida simulada");first=false;return base.Read(b,o,16);}
}
'@
Add-Type -TypeDefinition $code
[void][Net.WebRequest]::RegisterPrefix('https://api.github.com/__targino-fixture/',(New-Object TestRequestCreator))
function Reject([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action}catch{$failed=$true};if(-not $failed){throw $Message}}
$normal=Join-Path $fixture 'normal.bin';Receive-FrontendFile 'https://api.github.com/__targino-fixture/normal' $normal 32 $null
if((Get-Item $normal).Length -ne 32){throw 'Download normal incompleto.'}
$partial=Join-Path $fixture 'partial.bin'
Reject {Receive-FrontendFile 'https://api.github.com/__targino-fixture/interrupt' $partial 32 $null} 'Nao detectou interrupcao.'
if((Get-Item $partial).Length -ne 16){throw 'Fixture nao interrompeu no meio do pacote.'}
$manifest=[pscustomobject]@{size=32;sha256=(Get-FileHash $normal).Hash}
Reject {Assert-FrontendPackage $partial $manifest} 'Pacote parcial aceito.'
Reject {Receive-FrontendFile 'https://api.github.com/__targino-fixture/timeout' (Join-Path $fixture 'timeout.bin') 32 $null} 'Timeout ignorado.'
Reject {Receive-FrontendFile 'https://api.github.com/__targino-fixture/oversize' (Join-Path $fixture 'oversize.bin') 32 $null} 'Tamanho excedido aceito.'
$cancel=Join-Path $fixture 'cancel';$progress={param($received,$total)[IO.File]::WriteAllText($cancel,'cancel')}.GetNewClosure()
Reject {Receive-FrontendFile 'https://api.github.com/__targino-fixture/normal' (Join-Path $fixture 'cancel.bin') 32 $progress $cancel} 'Cancelamento ignorado.'
Reject {Receive-FrontendFile 'https://api.github.com/__targino-fixture/normal' $normal 32 $null} 'Sobrescreveu arquivo existente.'
if((Get-Item $normal).Length -ne 32){throw 'Arquivo anterior alterado.'}
$handle=[IO.File]::Open($partial,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$handle.Dispose()
Write-Output 'PASS: download normal, conexao interrompida, timeout, excesso de tamanho, cancelamento, parcial rejeitado e handles liberados; sem internet real.'
