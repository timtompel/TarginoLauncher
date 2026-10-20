$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\Input.ps1')
if((Get-GridNavigationIndex 0 21 5 'Left') -ne 0){throw 'Limite esquerdo incorreto'}
if((Get-GridNavigationIndex 4 21 5 'Right') -ne 5){throw 'Quebra de linha incorreta'}
if((Get-GridNavigationIndex 2 21 5 'Down') -ne 7){throw 'Navegacao vertical incorreta'}
if((Get-GridNavigationIndex 18 21 5 'Down') -ne 20){throw 'Ultima linha incompleta incorreta'}
if((Get-GridNavigationIndex 0 0 1 'Right') -ne -1){throw 'Lista vazia incorreta'}
$script:AppRoot=Join-Path ([IO.Path]::GetTempPath()) ('CentralInputTest-'+[Guid]::NewGuid().ToString('N'))
$map=Read-ControlMap
$state=[pscustomobject]@{Kind='WinMM';Buttons=4}
$buttons=Convert-PadButtons $state $map
if(-not $buttons.Confirm -or $buttons.Back){throw 'SNES botao 3 incorreto'}
$state=[pscustomobject]@{Kind='XInput';Buttons=4096}
if(-not (Convert-PadButtons $state $map).Confirm){throw 'Xbox A incorreto'}
$state=[pscustomobject]@{Kind='WinMM';Buttons=257}
$buttons=Convert-PadButtons $state $map
if(-not $buttons.Actions -or -not $buttons.Platforms){throw 'Select+Y incorreto'}
Add-Type -Path (Join-Path $PSScriptRoot '..\src\ControllerNative.cs')
$pad=[CentralInput.Native]::Poll()
Write-Output 'PASS: setas, limites, linhas incompletas, lista vazia, botoes SNES/Xbox e Select+Y.'
Write-Output ('Dispositivo detectado: '+$(if($pad.Device){$pad.Device}else{'nenhum conectado'}))
