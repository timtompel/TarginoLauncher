$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
. (Join-Path $PSScriptRoot '..\src\BaseUpdate.ps1')
if((Compare-BasePackage '"abc"' '"abc"') -ne 'current'){throw 'Igualdade falhou'}
if((Compare-BasePackage '"abc"' '"def"') -ne 'changed'){throw 'Mudanca falhou'}
if((Compare-BasePackage '' '"def"') -ne 'unknown'){throw 'Sem registro nao pode afirmar atualizacao'}
if((Compare-BasePackage '"abc"' '') -ne 'unknown'){throw 'Sem identificador remoto nao pode afirmar atualizacao'}
Write-Output 'PASS: pacote igual, pacote alterado e identificadores ausentes.'
