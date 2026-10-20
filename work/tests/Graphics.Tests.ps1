$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
. (Join-Path $PSScriptRoot '..\src\Graphics.ps1')
$sandbox=Join-Path ([IO.Path]::GetTempPath()) ('CentralGraphics-'+[Guid]::NewGuid().ToString('N'))
$gameDir=Join-Path $sandbox 'Jogo';$app=Join-Path $sandbox 'Launcher'
New-Item -ItemType Directory -Path $gameDir,$app|Out-Null
[IO.File]::WriteAllText((Join-Path $gameDir 'Zelda64Recompiled.exe'),'fixture, nao executar')
[IO.File]::WriteAllText((Join-Path $gameDir 'portable.txt'),'')
$config=Join-Path $gameDir 'graphics.json'
$original='{ "api_option": "Auto", "rr_manual_value": 60, "custom_option": "preservar" }'
[IO.File]::WriteAllText($config,$original,[Text.UTF8Encoding]::new($false))
$game=[pscustomobject]@{id='teste';executable='Jogo\Zelda64Recompiled.exe'}
$s=Get-GraphicsSupport $game $sandbox
if(-not $s.Supported -or 'OpenGL' -in $s.Options -or 'Software' -in $s.Options){throw 'Perfil incorreto'}
Save-GraphicsPreference $game $sandbox $app 'Vulkan'
if([IO.File]::ReadAllText($config) -ne $original){throw 'Salvar preferencia alterou jogo antes de jogar'}
Apply-GraphicsPreference $game $sandbox $app
$data=Read-CentralJson $config
if($data.api_option -ne 'Vulkan' -or $data.custom_option -ne 'preservar' -or $data.rr_manual_value -ne 60){throw 'Alterou outros ajustes'}
$backups=@(Get-ChildItem -LiteralPath (Join-Path $app 'Dados\BackupsGraficos\teste') -File)
if($backups.Count -ne 1 -or [IO.File]::ReadAllText($backups[0].FullName) -ne $original){throw 'Backup incorreto'}
Save-GraphicsPreference $game $sandbox $app 'D3D12';Apply-GraphicsPreference $game $sandbox $app
if((Read-CentralJson $config).api_option -ne 'D3D12'){throw 'Direct3D 12 nao aplicado'}
Save-GraphicsPreference $game $sandbox $app 'Auto';Apply-GraphicsPreference $game $sandbox $app
if((Read-CentralJson $config).api_option -ne 'Auto'){throw 'Automatico nao aplicado'}
try{Save-GraphicsPreference $game $sandbox $app 'Software';throw 'Aceitou software'}catch{if($_.Exception.Message -eq 'Aceitou software'){throw}}
$hash=(Get-FileHash -LiteralPath $config).Hash
[IO.File]::WriteAllText($config,'JSON corrompido')
try{Apply-GraphicsPreference $game $sandbox $app;throw 'Aceitou arquivo corrompido'}catch{if($_.Exception.Message -eq 'Aceitou arquivo corrompido'){throw}}
if([IO.File]::ReadAllText($config) -ne 'JSON corrompido'){throw 'Sobrescreveu configuracao corrompida'}
Write-Output 'PASS: perfis, preferencia isolada, Vulkan/D3D12/Auto, backup, preservacao de outros ajustes, bloqueio de software e JSON corrompido.'
