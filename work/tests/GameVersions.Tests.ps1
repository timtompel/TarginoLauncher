$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
. (Join-Path $PSScriptRoot '..\src\GameVersions.ps1')
function Assert($value,$message){if(-not $value){throw $message}}
function Reject([scriptblock]$action){$failed=$false;try{& $action|Out-Null}catch{$failed=$true};Assert $failed 'Metadado incorreto aceito.'}
$meta=[pscustomobject]@{messages=@([pscustomobject]@{id=999;text="Versao`nmstan - 0.1.0"},[pscustomobject]@{id=705;text="Versão`nmstan - 0.0.5-alpha"})}
$link='https://t.me/CentralArquivista/686/705'
$exportArgs=Get-ArquivistaMetadataArguments $link 'type=file,path=fixture' 'metadata.json'
$index=[Array]::IndexOf($exportArgs,'-i')
Assert ($exportArgs[$index+1] -eq '704,706') 'Consulta voltou a exportar todo o historico.'
$first=Get-ArquivistaPostReference 'https://t.me/Canal/1'
Assert ($first.lower -eq 1 -and $first.upper -eq 2) 'Limite inicial incorreto.'
$private=Get-ArquivistaPostReference 'https://t.me/c/12345/705'
Assert ($private.chat -eq '-10012345' -and $private.messageId -eq '705') 'Referencia privada incorreta.'
$v=Get-ArquivistaMessageVersion $meta $link
Assert ($v.version -eq '0.0.5-alpha' -and $v.messageId -eq '705') 'Pegou versao de outro post.'
Reject {Get-ArquivistaMessageVersion $meta 'https://t.me/Canal/123'}
Reject {Get-ArquivistaMessageVersion $meta 'https://example.com/705'}
Reject {Get-ArquivistaMessageVersion ([pscustomobject]@{messages=@($meta.messages[1],$meta.messages[1])}) $link}
Reject {Get-ArquivistaMessageVersion ([pscustomobject]@{messages=@([pscustomobject]@{id=705;text='Sem versao'})}) $link}
$fixture=Join-Path $PSScriptRoot ('versions-fixture-'+[guid]::NewGuid().ToString('N'))
$job=Join-Path $fixture 'Cache\Operacoes\teste'
New-Item -ItemType Directory -Force -Path $job,(Join-Path $fixture 'Dados'),(Join-Path $fixture 'Arquivismo\Dados'),(Join-Path $fixture 'Arquivismo\Cache')|Out-Null
function Save($relative,$data){[IO.File]::WriteAllText((Join-Path $fixture $relative),($data|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($true))}
Save 'Dados\instalados.json' @{teste=@{version='0.1.0';root=(Join-Path $fixture 'Biblioteca\teste');executable='jogo.exe'}}
Save 'Cache\Operacoes\teste\request.json' @{id='teste';link=$link}
Save 'Cache\Operacoes\teste\status.json' @{id='teste';state='done';executable='jogo.exe'}
Save 'Cache\Operacoes\teste\metadata.json' $meta
Repair-ManagedGameVersions $fixture
$record=(Read-CentralJson (Join-Path $fixture 'Dados\instalados.json')).teste
Assert ($record.version -eq '0.0.5-alpha' -and $record.versionSource -eq 'arquivista-message') 'Registro antigo nao reparado.'
Assert (@(Get-ChildItem (Join-Path $fixture 'Dados') -Filter '*.bak').Count -eq 1) 'Backup nao criado.'
Repair-ManagedGameVersions $fixture
Assert (@(Get-ChildItem (Join-Path $fixture 'Dados') -Filter '*.bak').Count -eq 1) 'Reparo repetido.'
Save 'Arquivismo\Dados\verificacao_acervo.json' @{Quando='19/10/2026 22:34';Jogos=@{teste=@{Ver='0.0.5-alpha';Err=''};outro=@{Ver='1.0';Err=''}}}
Save 'Arquivismo\Cache\verificacao_jogos.json' @{Quando='20/10/2026 10:00';Jogos=@{teste=@{Ver='0.0.6';Err=''};outro=@{Ver='2.0';Err='falha'}}}
$acervo=Read-ArquivistaAcervoVersions $fixture
Assert ($acervo.teste.version -eq '0.0.6' -and $acervo.outro.version -eq '') 'Conferencia mais nova/erro nao respeitada.'
Assert ((Read-CentralJson (Join-Path $fixture 'Dados\instalados.json')).teste.version -eq '0.0.5-alpha') 'Acervo sobrescreveu versao instalada.'
Assert ((Compare-LauncherVersions '0.0.5' '0.0.6') -lt 0) 'Comparacao de versoes crescentes falhou.'
Assert ((Compare-LauncherVersions 'v1.2.0-beta' '1.1.9') -gt 0) 'Comparacao de versoes com previa falhou.'
Assert ((Compare-LauncherVersions '1.0' '1.0.0') -eq 0) 'Zeros finais deveriam ser equivalentes.'
Write-Output 'PASS: ID exato, mensagem ausente/duplicada, reparo com backup idempotente, acervo mais novo e separacao entre instalada/disponivel.'
