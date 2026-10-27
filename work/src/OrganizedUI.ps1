. (Join-Path $PSScriptRoot 'GameRemoval.ps1')
function Show-LauncherAbout {
    $about=New-Object Windows.Window;$about.Title='Sobre o TarginoLauncher';$about.Width=540;$about.SizeToContent='Height';$about.MaxHeight=650;$about.WindowStartupLocation='CenterOwner';$about.ResizeMode='NoResize';$about.Background='#1B2428';$about.Foreground='White';$about.FontFamily='Segoe UI'
    if(-not $Verify){$about.Owner=$window}
    Enable-ModalKeyboard $about
    $scroll=New-Object Windows.Controls.ScrollViewer;$scroll.VerticalScrollBarVisibility='Auto';$about.Content=$scroll
    $panel=New-Object Windows.Controls.StackPanel;$panel.Margin='24';$scroll.Content=$panel
    $brand=New-Object Windows.Controls.StackPanel;$brand.Orientation='Horizontal';$brand.Margin='0,0,0,16'
    $icon=Join-Path $script:AppRoot 'Recursos\TarginoLauncher.ico'
    if(Test-Path -LiteralPath $icon){
        $decoder=[Windows.Media.Imaging.BitmapDecoder]::Create([Uri]$icon,[Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        $frame=$decoder.Frames|Sort-Object PixelWidth -Descending|Select-Object -First 1
        $frame.Freeze();$about.Icon=$frame
        $avatar=New-Object Windows.Controls.Image;$avatar.Source=$frame;$avatar.Width=56;$avatar.Height=56;$avatar.Stretch='Uniform';$avatar.Margin='0,0,14,0'
        [Windows.Media.RenderOptions]::SetBitmapScalingMode($avatar,[Windows.Media.BitmapScalingMode]::HighQuality)
        [void]$brand.Children.Add($avatar)
    }
    $heading=New-Object Windows.Controls.TextBlock;$heading.Text='TarginoLauncher';$heading.FontSize=25;$heading.FontWeight='SemiBold';$heading.VerticalAlignment='Center';[void]$brand.Children.Add($heading);[void]$panel.Children.Add($brand)
    $version='nao informada';$channel='nao informado'
    $versionFile=Join-Path $script:AppRoot 'versao.json'
    if(Test-Path -LiteralPath $versionFile){try{$release=Read-CentralJson $versionFile;$version=[string]$release.version;if($release.PSObject.Properties['channel']){$channel=[string]$release.channel}}catch{$version='indisponivel'}}
    $info=New-Object Windows.Controls.TextBlock;$info.Text="Versao instalada: $version`nCanal: $channel`n`nRecompilados by Central Arquivista`n`nInterface comunitaria independente por Targino Social Media.`nCreditos da base: projeto Central Arquivista.`nCria uma biblioteca propria na pasta Biblioteca para os jogos baixados por ele, separada do Central original.`nEste frontend nao substitui a autoria do programa original e nao inclui jogos.`n`nCreditos e licencas das imagens: Recursos\Controles\CREDITOS.txt e Recursos\Plataformas\CREDITOS.txt.";$info.TextWrapping='Wrap';$info.FontSize=14;$info.Margin='0,0,0,18';[void]$panel.Children.Add($info)
    foreach($entry in @(@{label='Projeto no GitHub';url='https://github.com/timtompel/TarginoLauncher'},@{label='Canal no Telegram';url='https://t.me/TarginoLauncher'})){
        $link=New-Object Windows.Controls.Button;$link.Content=$entry.label;$link.Tag=$entry.url;$link.Padding='12,9';$link.Margin='0,0,0,8'
        $link.Add_Click({param($sender,$eventArgs) $open=New-Object Diagnostics.ProcessStartInfo;$open.FileName=[string]$sender.Tag;$open.UseShellExecute=$true;try{[void][Diagnostics.Process]::Start($open)}catch{[void][Windows.MessageBox]::Show($_.Exception.Message,'Abrir link')}});[void]$panel.Children.Add($link)
    }
    $close=New-Object Windows.Controls.Button;$close.Content='Fechar';$close.IsCancel=$true;$close.Padding='12,9';$close.Add_Click({$about.Close()}.GetNewClosure());[void]$panel.Children.Add($close)
    $about.Add_ContentRendered({[void]$close.Focus()}.GetNewClosure())
    if($Verify){return $about}
    [void]$about.ShowDialog()
}
function Show-LauncherActionList([string]$MenuTitle,$Actions) {
    $dialog=New-Object Windows.Window;if(-not $Verify){$dialog.Owner=$window};$dialog.Title=$MenuTitle;$dialog.Width=460;$dialog.SizeToContent='Height';$dialog.MaxHeight=650;$dialog.WindowStartupLocation='CenterOwner';$dialog.Background='#1B2428';$dialog.Foreground='White';$dialog.FontFamily='Segoe UI';$dialog.ResizeMode='NoResize'
    Enable-ModalKeyboard $dialog
    $scroll=New-Object Windows.Controls.ScrollViewer;$scroll.VerticalScrollBarVisibility='Auto'
    $panel=New-Object Windows.Controls.StackPanel;$panel.Margin='22';$scroll.Content=$panel;$dialog.Content=$scroll
    $heading=New-Object Windows.Controls.TextBlock;$heading.Text=$MenuTitle;$heading.FontSize=21;$heading.TextWrapping='Wrap';$heading.Margin='0,0,0,18';[void]$panel.Children.Add($heading)
    foreach($action in $Actions){
        $button=New-Object Windows.Controls.Button;$button.Content=$action.label;$button.Tag=$action.source;$button.IsEnabled=[bool]$action.enabled;$button.Padding='14,10';$button.Margin='0,0,0,8';$button.HorizontalContentAlignment='Left'
        $button.Add_Click({param($sender,$e) $dialog.Tag=$sender.Tag;$dialog.DialogResult=$true}.GetNewClosure());[void]$panel.Children.Add($button)
    }
    $back=New-Object Windows.Controls.Button;$back.Content='Voltar';$back.Padding='14,10';$back.Margin='0,10,0,0';$back.IsCancel=$true;$back.Add_Click({$dialog.Close()}.GetNewClosure());[void]$panel.Children.Add($back)
    $dialog.Add_ContentRendered({if($panel.Children.Count -gt 1){[void]$panel.Children[1].Focus()}}.GetNewClosure())
    if($Verify){return $dialog}
    $result=$dialog.ShowDialog();$source=$dialog.Tag
    if($result -eq $true -and $source){
        try{$source.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))}
        catch{Write-LauncherLog 'ui.action' $_.Exception.ToString();[void][Windows.MessageBox]::Show($window,('Nao foi possivel executar a opcao: '+$_.Exception.Message),'TarginoLauncher')}
    }
}
function Show-GameRemovalDialog {
    if(-not $script:Selected){return}
    if($script:ActiveInstall -or $script:DownloadQueue.Count -or ($script:FrontendProcess -and -not $script:FrontendProcess.HasExited)){throw 'Aguarde as operacoes em andamento antes de desinstalar.'}
    $game=$script:Selected;$plan=Get-GameRemovalPlan $game $script:AppRoot
    $dialog=New-Object Windows.Window;$dialog.Title='Desinstalar jogo';$dialog.Owner=$window;$dialog.Width=510;$dialog.SizeToContent='Height';$dialog.WindowStartupLocation='CenterOwner';$dialog.ResizeMode='NoResize'
    Enable-ModalKeyboard $dialog
    $panel=New-Object Windows.Controls.StackPanel;$panel.Margin='24';$dialog.Content=$panel
    $text=New-Object Windows.Controls.TextBlock;$text.Text='Desinstalar '+$game.title+"?`n`nA pasta sera enviada a Lixeira do Windows. O jogo continuara no catalogo para baixar novamente. Esvazie a Lixeira manualmente se quiser liberar o espaco.`n`nSomente esta pasta sera removida:`n"+$plan.root;$text.TextWrapping='Wrap';[void]$panel.Children.Add($text)
    $preserve=New-Object Windows.Controls.CheckBox;$preserve.Content='Salvar backup dos saves e configuracoes reconhecidos';$preserve.IsChecked=$true;$preserve.Margin='0,20,0,8';[void]$panel.Children.Add($preserve)
    $notice=New-Object Windows.Controls.TextBlock;$notice.Text='Saves fora da pasta do jogo nao sao tocados. Nem todos os formatos podem ser identificados.';$notice.TextWrapping='Wrap';$notice.Margin='0,0,0,16';[void]$panel.Children.Add($notice)
    $cancel=New-Object Windows.Controls.Button;$cancel.Content='Cancelar';$cancel.IsCancel=$true;$cancel.Padding='12,8';$cancel.Margin='0,0,0,8';$cancel.Add_Click({$dialog.Close()}.GetNewClosure());[void]$panel.Children.Add($cancel)
    $yes=New-Object Windows.Controls.Button;$yes.Content='Confirmar desinstalacao';$yes.Padding='12,8';$yes.Add_Click({$dialog.DialogResult=$true}.GetNewClosure());[void]$panel.Children.Add($yes)
    $dialog.Add_ContentRendered({[void]$cancel.Focus()}.GetNewClosure())
    if($dialog.ShowDialog() -ne $true){return}
    try{
        $window.Cursor=[Windows.Input.Cursors]::Wait
        $result=Remove-ManagedGame $game $script:AppRoot ([bool]$preserve.IsChecked)
        Load-Catalog
        $message='Jogo enviado a Lixeira. Pode ser baixado novamente.'
        if($result.saveBackup){$message+="`nBackup dos saves/configuracoes: "+$result.saveBackup}
        [void][Windows.MessageBox]::Show($window,$message,'Desinstalacao concluida')
    }finally{$window.Cursor=$null}
}
$script:UninstallGameButton=New-Object Windows.Controls.Button
$UninstallGameButton.Add_Click({try{Show-GameRemovalDialog}catch{[void][Windows.MessageBox]::Show($window,$_.Exception.Message,'Desinstalar jogo')}})
$script:GameOptionsButton=New-Object Windows.Controls.Button;$GameOptionsButton.Content='Opcoes do jogo';$GameOptionsButton.FontSize=15
[void]$Play.Parent.Children.Add($GameOptionsButton)
# Acoes principais fixas: nao ficam escondidas abaixo da sinopse.
$primaryActions=$Play.Parent;[void]$primaryActions.Parent.Children.Remove($primaryActions)
$primaryActions.Margin='0,12,0,0'
foreach($control in @($Play,$GameOptionsButton,$cancelButton)){$control.FontSize=14;$control.Padding='12,9'}
$detailBorder.Child=$null
$detailDock=New-Object Windows.Controls.DockPanel
[Windows.Controls.DockPanel]::SetDock($primaryActions,'Bottom');[void]$detailDock.Children.Add($primaryActions);[void]$detailDock.Children.Add($detailScroll);$detailBorder.Child=$detailDock
$GameOptionsButton.Add_Click({
    if(-not $script:Selected){return}
    $installed=[IO.File]::Exists((Resolve-CatalogPath (Get-GameRoot $script:Selected) $script:Selected.executable))
    $canRemove=$false;try{[void](Get-GameRemovalPlan $script:Selected $script:AppRoot);$canRemove=$true}catch{}
    Show-LauncherActionList $script:Selected.title @(
        @{label='Ficha do jogo';source=$Details;enabled=$true},
        @{label='Atualizar jogo';source=$UpdateButton;enabled=$installed},
        @{label='Renderizador';source=$GraphicsButton;enabled=$GraphicsButton.IsEnabled},
        @{label='Editar jogo adicional';source=$editButton;enabled=[bool]$script:Selected.PSObject.Properties['libraryRoot']},
        @{label=$(if($canRemove){'Desinstalar jogo'}else{'Desinstalar (somente baixados aqui)'});source=$UninstallGameButton;enabled=$canRemove}
    )
})
# Os controles originais permanecem como destinos dos atalhos e eventos.
foreach($control in @($Details,$UpdateButton,$GraphicsButton,$editButton)){
    if($control.Parent -is [Windows.Controls.Panel]){[void]$control.Parent.Children.Remove($control)}
    $control.Visibility='Collapsed'
}
$Games.Add_SelectionChanged({foreach($control in @($Details,$UpdateButton,$GraphicsButton,$editButton)){$control.Visibility='Collapsed'};$GameOptionsButton.IsEnabled=($null -ne $script:Selected)})
$GraphicsInfo.Visibility='Collapsed'
$headerActions=$Reload.Parent;$Reload.Visibility='Collapsed';$connectButton.Visibility='Collapsed';$ChooseRoot.Content='Biblioteca'
$settings=New-Object Windows.Controls.Button;$settings.Content='Configuracoes';$settings.Height=40;$settings.MinWidth=130;$settings.Padding='14,0';$settings.Margin='0';[void]$headerActions.Children.Add($settings)
$script:ControllerSettingsSource=New-Object Windows.Controls.Button;$ControllerSettingsSource.Add_Click({Show-ControlSettings})
$script:InstalledUpdatesSource=New-Object Windows.Controls.Button;$InstalledUpdatesSource.Add_Click({Show-InstalledGamesUpdate})
$script:AboutButton=New-Object Windows.Controls.Button;$AboutButton.Content='Sobre';$AboutButton.Add_Click({Show-LauncherAbout})
$script:CopyErrorButton=New-Object Windows.Controls.Button;$CopyErrorButton.Add_Click({try{[Windows.Clipboard]::SetText([string]$Status.Text);[void][Windows.MessageBox]::Show('Mensagem copiada para a area de transferencia.','TarginoLauncher')}catch{}})
$script:QueueButton=New-Object Windows.Controls.Button;$QueueButton.Add_Click({Show-DownloadQueue})
$settings.Add_Click({Show-LauncherActionList 'Configuracoes' @(
    @{label='Escolher biblioteca';source=$ChooseRoot;enabled=$true},
    @{label='Recarregar catalogo';source=$Reload;enabled=$true},
    @{label='Adicionar jogo';source=$homeAdd;enabled=$true},
    @{label='Configurar controle';source=$ControllerSettingsSource;enabled=$true},
    @{label='Conectar Telegram';source=$connectButton;enabled=$true},
    @{label='Verificar / atualizar launcher';source=$FrontendButton;enabled=$FrontendButton.IsEnabled},
    @{label='Cancelar atualizacao do launcher';source=$CancelFrontendButton;enabled=([bool]$script:FrontendProcess -and -not $script:FrontendProcess.HasExited)},
    @{label='Verificar Central original';source=$baseCheckButton;enabled=$baseCheckButton.IsEnabled},
    @{label='Atualizar Central original (oficial)';source=$OfficialBaseUpdateButton;enabled=([bool]$script:BaseLatestResult -and $script:BaseLatestResult.state -eq 'changed' -and $script:BaseLatestRoot -eq $script:GamesRoot)},
    @{label=('Atualizar jogos instalados ('+(@(Get-InstalledUpdateCandidates).Count)+')');source=$InstalledUpdatesSource;enabled=(@(Get-InstalledUpdateCandidates).Count -gt 0)},
    @{label=('Fila de downloads ('+($script:DownloadQueue.Count+$(if($script:ActiveInstall){1}else{0}))+'; '+$script:DownloadQueue.Count+' aguardando)');source=$QueueButton;enabled=($script:DownloadQueue.Count -gt 0)},
    @{label='Copiar ultima mensagem / erro';source=$CopyErrorButton;enabled=(-not [string]::IsNullOrWhiteSpace($Status.Text))},
    @{label='Sobre';source=$AboutButton;enabled=$true}
)})
foreach($child in $PlatformHome.Children){if($child -is [Windows.Controls.Button]){$child.Visibility='Collapsed'}}
$addButton.Visibility='Collapsed'
$baseCheckButton.Visibility='Collapsed';$FrontendButton.Visibility='Collapsed'
$baseUpdateBar.Visibility='Collapsed';$frontendBar.Visibility='Collapsed'
$script:CompactUpdateText=New-Object Windows.Controls.TextBlock;$CompactUpdateText.Margin='22,6';$CompactUpdateText.Foreground='#BDCEBF';$CompactUpdateText.FontSize=12;$CompactUpdateText.TextWrapping='Wrap'
$headerRoot=$window.FindName('ClockTime');while($headerRoot.Parent -ne $window.Content){$headerRoot=$headerRoot.Parent}
$afterHeader=$window.Content.Children.IndexOf($headerRoot)+1
[Windows.Controls.DockPanel]::SetDock($CompactUpdateText,'Top');$window.Content.Children.Insert($afterHeader,$CompactUpdateText)
$script:CompactProgress=New-Object Windows.Controls.ProgressBar;$CompactProgress.Height=6;$CompactProgress.Margin='22,0,22,4';$CompactProgress.Visibility='Collapsed'
[Windows.Controls.DockPanel]::SetDock($CompactProgress,'Top');$window.Content.Children.Insert(($afterHeader+1),$CompactProgress)
$cleanTimer=New-Object Windows.Threading.DispatcherTimer;$cleanTimer.Interval=[TimeSpan]::FromMilliseconds(350)
function Update-CompactStatus {
    $text=$FrontendText.Text
    if($script:BaseCheck){$text='Consultando atualizacao do Central original...'}
    elseif($script:BaseLatestResult -and $script:BaseLatestRoot -eq $script:GamesRoot){$text='Central v'+$script:BaseLatestResult.version+': '+$script:BaseLatestResult.message+' | '+$FrontendText.Text}
    if($script:OfficialBaseUpdate){$text='Atualizacao do Central original em andamento; acompanhe a janela oficial.'}
    elseif($script:BaseLatestResult -and $script:BaseLatestRoot -eq $script:GamesRoot -and $script:BaseLatestResult.state -eq 'changed'){$text='Atualizacao do Central disponivel — Configuracoes > Atualizar Central original (oficial)'}
    if($script:FrontendPending){$text+=' — Configuracoes > Verificar / atualizar launcher'}
    $CompactUpdateText.Text=$text;$CompactUpdateText.ToolTip=$BaseUpdateText.Text
    $CompactProgress.Visibility=$FrontendProgress.Visibility;$CompactProgress.IsIndeterminate=$FrontendProgress.IsIndeterminate;$CompactProgress.Value=$FrontendProgress.Value
    foreach($control in @($GraphicsButton,$editButton,$UpdateButton)){$control.Visibility='Collapsed'}
    Update-LauncherFooter
}
$cleanTimer.Add_Tick({Update-CompactStatus})
$cleanTimer.Start();$window.Add_Closed({$cleanTimer.Stop()})
$iconPath=Join-Path $script:AppRoot 'Recursos\TarginoLauncher.ico'
if(Test-Path -LiteralPath $iconPath){
    $window.Icon=[Windows.Media.Imaging.BitmapFrame]::Create([Uri]$iconPath)
    $brand=$window.FindName('ClockTime');while($brand.Parent -ne $window.Content){$brand=$brand.Parent}
    $brandGrid=$brand.Child;$brandText=$brandGrid.Children[0]
    [void]$brandGrid.Children.Remove($brandText)
    $brandRow=New-Object Windows.Controls.StackPanel;$brandRow.Orientation='Horizontal';$brandRow.VerticalAlignment='Center'
    $brandFrames=[Windows.Media.Imaging.BitmapDecoder]::Create([Uri]$iconPath,[Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    $brandAvatar=New-Object Windows.Controls.Image;$brandAvatar.Source=($brandFrames.Frames|Sort-Object PixelWidth -Descending|Select-Object -First 1);$brandAvatar.Width=62;$brandAvatar.Height=62;$brandAvatar.Stretch='Uniform';$brandAvatar.Margin='0,0,14,0'
    [void]$brandRow.Children.Add($brandAvatar);[void]$brandRow.Children.Add($brandText);[void]$brandGrid.Children.Add($brandRow)
}
$InputHint.Visibility='Collapsed'
$footer=New-Object Windows.Controls.Border;$footer.Background='#172520';$footer.BorderBrush='#526258';$footer.BorderThickness='0,1,0,0';$footer.Padding='20,10'
[Windows.Controls.DockPanel]::SetDock($footer,'Bottom');$window.Content.Children.Insert(0,$footer)
$footerGrid=New-Object Windows.Controls.Grid
$column=New-Object Windows.Controls.ColumnDefinition;$column.Width=[Windows.GridLength]::new(1,[Windows.GridUnitType]::Star);[void]$footerGrid.ColumnDefinitions.Add($column)
$column=New-Object Windows.Controls.ColumnDefinition;$column.Width=[Windows.GridLength]::Auto;[void]$footerGrid.ColumnDefinitions.Add($column)
$footer.Child=$footerGrid
$footerKeys=New-Object Windows.Controls.WrapPanel;$footerKeys.VerticalAlignment='Center';[void]$footerGrid.Children.Add($footerKeys)
foreach($pair in @(@('Setas','Navegar'),@('Enter / A','Confirmar'),@('Esc / B','Voltar'),@('D / X','Detalhes'),@('F','Buscar'),@('F11','Tela cheia'))){
    $group=New-Object Windows.Controls.StackPanel;$group.Orientation='Horizontal';$group.Margin='0,3,16,3'
    $badge=New-Object Windows.Controls.Border;$badge.Background='#33463C';$badge.CornerRadius='4';$badge.Padding='7,4';$badge.Margin='0,0,6,0'
    $label=New-Object Windows.Controls.TextBlock;$label.Text=$pair[0];$label.FontWeight='SemiBold';$label.Foreground='White';$label.FontSize=12;$badge.Child=$label
    [void]$group.Children.Add($badge)
    $label=New-Object Windows.Controls.TextBlock;$label.Text=$pair[1];$label.Foreground='#CAD7CE';$label.VerticalAlignment='Center';$label.FontSize=12;[void]$group.Children.Add($label);[void]$footerKeys.Children.Add($group)
}
$script:FooterController=New-Object Windows.Controls.Button;$FooterController.Background='Transparent';$FooterController.Padding='8,6';$FooterController.Margin='12,0,0,0';$FooterController.FontSize=13;$FooterController.VerticalAlignment='Center';[Windows.Controls.Grid]::SetColumn($FooterController,1);[void]$footerGrid.Children.Add($FooterController)
$FooterController.Add_Click({Show-ControlSettings})
function Update-LauncherFooter {
    $pad=[CentralInput.Native]::Poll()
    if($pad.Device){
        $style=Get-ControllerVisualStyle $pad
        $label=switch($style){Xbox{'Xbox / XInput'}Sony{'Sony'}PS2{'PS2'}SNES{'SNES'}MegaDrive{'Mega Drive'}default{'Generico'}}
        $FooterController.Content='Controle conectado  |  '+$label
        $FooterController.Foreground='#94DE92'
        $FooterController.ToolTip=$pad.Device+"`nClique para configurar e testar os botoes."
    }else{
        $FooterController.Content='Controle desconectado';$FooterController.Foreground='#B4BDB8';$FooterController.ToolTip='Clique para configurar o controle. O teclado continua disponivel.'
    }
}
Update-LauncherFooter
