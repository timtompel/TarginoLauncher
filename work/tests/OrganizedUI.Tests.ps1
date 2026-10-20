param([Parameter(Mandatory)][string]$AppRoot)
$ErrorActionPreference='Stop'
. (Join-Path $AppRoot 'src\CentralArquivista.ps1') -Verify
if(-not $window.Icon){throw 'Icone da janela nao carregou.'}
if($Play.Parent.Children -notcontains $GameOptionsButton){throw 'Menu do jogo ausente.'}
foreach($control in @($Details,$UpdateButton,$GraphicsButton,$editButton)){if($control.Parent){throw ('Acao secundaria ainda ocupa painel: '+$control.Content)}}
if($settings.Content -ne 'Configuracoes' -or $Reload.Visibility -ne 'Collapsed' -or $connectButton.Visibility -ne 'Collapsed'){throw 'Cabecalho nao organizado.'}
if($frontendBar.Visibility -ne 'Collapsed' -or $baseUpdateBar.Visibility -ne 'Collapsed'){throw 'Barras redundantes ainda visiveis.'}
$launch=Get-OfficialBaseLaunchInfo $script:GamesRoot
if($launch.info.WorkingDirectory -ne $script:GamesRoot -or $launch.info.Arguments -notlike '*Arquivismo\Launcher.ps1*'){throw 'Integracao nao aponta para o programa oficial.'}
if($script:OfficialBaseUpdate){throw 'Teste nao deve executar o Central original.'}
# Regressao: titulo do menu nao pode sombrear o TextBlock global de titulo do jogo.
$commandInfo=Get-Command Show-LauncherActionList
if($commandInfo.Parameters.ContainsKey('Title')){throw 'Parametro do menu volta a sombrear controle Title.'}
& {param([string]$MenuTitle) $Reload.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))} 'Configuracoes'
if($Title -isnot [Windows.Controls.TextBlock] -or $homeHeading.Text -like 'Falha*' -or $Games.Items.Count -eq 0){throw 'Recarregamento via menu falhou.'}
$script:BaseLatestResult=[pscustomobject]@{state='current';version='teste';message='Pacote confere.'};$script:BaseLatestRoot=$script:GamesRoot
Update-CompactStatus
if($CompactUpdateText.Text -notlike '*Central vteste: Pacote confere.*'){throw 'Resultado da consulta da base nao esta visivel.'}
$script:BaseCheck=@{test=$true};Update-CompactStatus
if($CompactUpdateText.Text -notlike 'Consultando*'){throw 'Consulta em andamento nao aparece.'}
$script:BaseCheck=$null;$script:BaseLatestResult=$null
# Renderizacao headless do conteudo real, sem capturar a area de trabalho.
$content=$window.Content
$content.Measure([Windows.Size]::new(1400,820));$content.Arrange([Windows.Rect]::new(0,0,1400,820));$content.UpdateLayout()
$bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 1400,820,96,96,([Windows.Media.PixelFormats]::Pbgra32)
$background=New-Object Windows.Media.DrawingVisual;$drawing=$background.RenderOpen();$drawing.DrawRectangle($window.Background,$null,[Windows.Rect]::new(0,0,1400,820));$drawing.Close();$bitmap.Render($background)
$bitmap.Render($content)
$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$output=Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'outputs\Launcher-organizado-preview.png'
$stream=[IO.File]::Create($output);try{$encoder.Save($stream)}finally{$stream.Dispose()}
Show-PlatformHome
$content.Measure([Windows.Size]::new(1600,860));$content.Arrange([Windows.Rect]::new(0,0,1600,860));$content.UpdateLayout();Update-PlatformLayout;$content.UpdateLayout()
if($PlatformStrip -isnot [Windows.Controls.Primitives.UniformGrid] -or $PlatformStrip.Columns -lt 1){throw 'Grade responsiva nao foi aplicada.'}
$columnsBefore=$PlatformStrip.Columns;$heightBefore=$PlatformStrip.Height
Build-PlatformButtons;$content.UpdateLayout();Update-PlatformLayout;$content.UpdateLayout()
if($PlatformStrip.Columns -ne $columnsBefore -or [Math]::Abs($PlatformStrip.Height-$heightBefore) -gt 1){throw 'Reconstruir os botoes alterou o layout na mesma janela.'}
foreach($card in $PlatformStrip.Children){
    if(-not [double]::IsNaN($card.Child.Height) -or $card.Background -ne $card.Child.Background){throw 'Cartao voltou a ter faixas de fundo diferentes.'}
    if([Math]::Abs(($card.ActualHeight-4)-$card.Child.ActualHeight) -gt 1){throw 'Botao nao preenche a altura do cartao.'}
}
$bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 1600,860,96,96,([Windows.Media.PixelFormats]::Pbgra32)
$background=New-Object Windows.Media.DrawingVisual;$drawing=$background.RenderOpen();$drawing.DrawRectangle($window.Background,$null,[Windows.Rect]::new(0,0,1600,860));$drawing.Close();$bitmap.Render($background);$bitmap.Render($content)
$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$stream=[IO.File]::Create(($output -replace 'Launcher-organizado-preview','Plataformas-responsivas-preview'));try{$encoder.Save($stream)}finally{$stream.Dispose()}
Write-Output 'PASS: icone, acoes secundarias fora do painel, cabecalho compacto, integracao oficial da base sem executar e renderizacao headless.'
