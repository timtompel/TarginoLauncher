$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
. (Join-Path $PSScriptRoot '..\src\Input.ps1')
. (Join-Path $PSScriptRoot '..\src\ControllerVisuals.ps1')
Add-Type -Path (Join-Path $PSScriptRoot '..\src\ControllerNative.cs')
$states=@(
    @{state=[pscustomobject]@{Device='Xbox';Kind='XInput'};expected='Xbox'},
    @{state=[pscustomobject]@{Device='Sony DualSense';Kind='WinMM'};expected='Sony'},
    @{state=[pscustomobject]@{Device='USB PS2 Adapter';Kind='WinMM'};expected='PS2'},
    @{state=[pscustomobject]@{Device='SNES USB';Kind='WinMM'};expected='SNES'},
    @{state=[pscustomobject]@{Device='Mega Drive USB';Kind='WinMM'};expected='MegaDrive'},
    @{state=[pscustomobject]@{Device='Microsoft PC joystick';Kind='WinMM'};expected='Generic'}
)
foreach($test in $states){if((Get-ControllerVisualStyle $test.state) -ne $test.expected){throw 'Deteccao incorreta.'}}
$script:AppRoot=Join-Path $PSScriptRoot ('controller-fixture-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path (Join-Path $script:AppRoot 'Recursos')|Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\distribution-assets\Controles') -Destination (Join-Path $script:AppRoot 'Recursos\Controles') -Recurse
foreach($style in 'Xbox','Sony','PS2','SNES','MegaDrive','Generic'){
    $art=New-ControllerIllustration $style
    if($art.Child -isnot [Windows.Controls.Image] -or -not $art.Child.Source){throw ('Foto ausente: '+$style)}
    $art.Measure([Windows.Size]::new(440,170));$art.Arrange([Windows.Rect]::new(0,0,440,170));$art.UpdateLayout()
}
$script:ControlMap=Read-ControlMap;$Verify=$true;$window=New-Object Windows.Window
$dialog=Show-ControlSettings
if(-not(Test-ControlMappingWindow $dialog)){throw 'Janela de mapeamento nao isolada.'}
# Mesmo o comando Voltar ja convertido nao pode fechar a janela de captura.
function Get-ActiveLauncherWindow {return $dialog}
$closed=@{value=$false}
$dialog.Add_Closed({$closed.value=$true}.GetNewClosure())
Invoke-LauncherCommand 'Back'
Invoke-LauncherCommand 'Confirm'
if($closed.value){throw 'Comando do controle fechou a janela de mapeamento.'}
$capture=$dialog.Tag.capture
$capture.target=$capture.fields.Confirm
$original=$capture.fields.Confirm.Text
$state=[pscustomobject]@{Device='USB';Kind='WinMM';Buttons=[uint32]8}
Update-ControlMappingCapture $dialog.Tag $state
if($capture.fields.Confirm.Text -ne $original){throw 'Capturou botao ja segurado ao entrar no campo.'}
$state.Buttons=0;Update-ControlMappingCapture $dialog.Tag $state
$state.Buttons=8;Update-ControlMappingCapture $dialog.Tag $state
if($capture.fields.Confirm.Text -ne '4' -or $capture.fields.Details.Text -ne $original){throw 'Captura ou troca de atribuicoes falhou.'}
$state.Buttons=2;Update-ControlMappingCapture $dialog.Tag $state
if($capture.fields.Confirm.Text -ne '4'){throw 'Repetiu captura sem soltar.'}
$state.Buttons=0;Update-ControlMappingCapture $dialog.Tag $state
$state.Buttons=3;Update-ControlMappingCapture $dialog.Tag $state
if($capture.fields.Confirm.Text -ne '4'){throw 'Capturou multiplos botoes.'}
$capture.target=$null
if(-not $dialog.Tag.status.Text -or $dialog.Tag.ContainsKey('selector')){throw 'Preview nao inicializou ou ainda possui seletor.'}
$dialog.Tag.status.Text='aguardando tick'
$frame=New-Object Windows.Threading.DispatcherFrame
$stopTimer=New-Object Windows.Threading.DispatcherTimer;$stopTimer.Interval=[TimeSpan]::FromMilliseconds(500)
$stopTimer.Add_Tick({$frame.Continue=$false}.GetNewClosure());$stopTimer.Start()
[Windows.Threading.Dispatcher]::PushFrame($frame);$stopTimer.Stop()
if($dialog.Tag.status.Text -eq 'aguardando tick'){throw 'Estado do controle nao foi atualizado pelo timer.'}
Update-ControllerPreview $dialog
if($dialog.Tag.current -ne (Get-ControllerVisualStyle ([CentralInput.Native]::Poll()))){throw 'Foto nao segue identificacao automatica.'}
$dialog.Content.Measure([Windows.Size]::new(820,600));$dialog.Content.Arrange([Windows.Rect]::new(0,0,820,600));$dialog.Content.UpdateLayout()
$bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 860,640,96,96,([Windows.Media.PixelFormats]::Pbgra32)
$background=New-Object Windows.Media.DrawingVisual;$drawing=$background.RenderOpen();$drawing.DrawRectangle($dialog.Background,$null,[Windows.Rect]::new(0,0,860,640));$drawing.Close();$bitmap.Render($background);$bitmap.Render($dialog.Content)
$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$path=Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'outputs\Controle-ilustrado-preview.png'
$stream=[IO.File]::Create($path);try{$encoder.Save($stream)}finally{$stream.Dispose()}
$dialog.Tag.timer.Stop();$dialog.Close();$window.Close()
Write-Output 'PASS: deteccao automatica, seis fotos reais, ausencia de seletor e estado de conexao ao vivo.'
