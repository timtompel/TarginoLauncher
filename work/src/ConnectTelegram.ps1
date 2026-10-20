param([Parameter(Mandatory)][string]$Tool,[Parameter(Mandatory)][string]$Session)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path (Split-Path $Session -Parent)|Out-Null
Write-Host 'Conecte a conta para baixar os jogos. Escaneie o QR pelo Telegram do celular.'
& $Tool --storage ('type=file,path='+$Session) login --type qr
if($LASTEXITCODE -ne 0){Write-Host 'Nao foi possivel conectar. Tente novamente.';Read-Host 'Enter para fechar'}
