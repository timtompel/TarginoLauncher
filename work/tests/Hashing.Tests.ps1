$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '..\src\FrontendUpdate.ps1')
function Get-FileHash {throw 'Get-FileHash indisponivel: simulacao do ambiente afetado.'}
$fixture=Join-Path $PSScriptRoot ('hashing-fixture-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture|Out-Null
$file=Join-Path $fixture 'teste.bin'
[IO.File]::WriteAllText($file,'abc',[Text.Encoding]::ASCII)
$expected='BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'
if((Get-TarginoFileSHA256 $file) -cne $expected){throw 'SHA256 do vetor conhecido abc incorreto.'}
$manifest=[pscustomobject]@{size=3;sha256=$expected}
Assert-FrontendPackage $file $manifest
[IO.File]::WriteAllText($file,'abd',[Text.Encoding]::ASCII)
$blocked=$false;try{Assert-FrontendPackage $file $manifest}catch{$blocked=$true}
if(-not $blocked){throw 'Adulteracao de mesmo tamanho aceita.'}
$stream=[IO.File]::Open($file,'Open','ReadWrite','None');$stream.Dispose()
[IO.File]::WriteAllBytes($file,[byte[]]@())
if((Get-TarginoFileSHA256 $file) -cne 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'){throw 'Hash vazio incorreto.'}
$missing=$false;try{Get-TarginoFileSHA256 (Join-Path $fixture 'ausente')}catch{$missing=$true}
if(-not $missing){throw 'Arquivo ausente aceito.'}
Write-Output 'PASS: SHA256 nativo sem Get-FileHash, vetores abc/vazio, pacote valido, adulteracao rejeitada e handles liberados.'
