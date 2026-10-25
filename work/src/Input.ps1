function Get-GridNavigationIndex([int]$Index,[int]$Count,[int]$Columns,[string]$Direction){
    if($Count -le 0){return -1}
    $Columns=[Math]::Max(1,$Columns);$Index=[Math]::Max(0,[Math]::Min($Count-1,$Index))
    switch($Direction){
        Left {return [Math]::Max(0,$Index-1)}
        Right {return [Math]::Min($Count-1,$Index+1)}
        Up {if($Index -ge $Columns){return $Index-$Columns};return $Index}
        Down {if($Index+$Columns -lt $Count){return $Index+$Columns};if([Math]::Floor($Index/$Columns) -lt [Math]::Floor(($Count-1)/$Columns)){return $Count-1};return $Index}
    }
    return $Index
}
function Read-ControlMap {
    $map=@{Confirm=3;Back=2;Details=4;Platforms=1;PageLeft=5;PageRight=6;Actions=9;Start=10}
    $file=Join-Path $script:AppRoot 'Dados\controle.json'
    if(Test-Path -LiteralPath $file){$saved=Read-CentralJson $file;foreach($key in @($map.Keys)){if($saved.PSObject.Properties[$key]){$n=[int]$saved.$key;if($n -ge 1 -and $n -le 32){$map[$key]=$n}}}}
    return $map
}
function Convert-PadButtons($State,$Map){
    $result=@{}
    $x=@{Confirm=4096;Back=8192;Details=16384;Platforms=32768;PageLeft=256;PageRight=512;Actions=32;Start=16}
    foreach($key in $Map.Keys){$mask=if($State.Kind -eq 'XInput'){[uint32]$x[$key]}else{[uint32]1 -shl ($Map[$key]-1)};$result[$key]=(($State.Buttons -band $mask) -ne 0)}
    return $result
}
function Get-ActiveLauncherWindow {
    if(-not [CentralInput.Native]::IsForeground([uint32]$PID)){return $null}
    $queue=New-Object Collections.Queue;$queue.Enqueue($window)
    while($queue.Count){$candidate=$queue.Dequeue();if($candidate.IsActive){return $candidate};foreach($owned in $candidate.OwnedWindows){$queue.Enqueue($owned)}}
    return $null
}
function Test-ControlMappingWindow($Target){
    return ($null -ne $Target -and $Target.Tag -is [System.Collections.IDictionary] -and $Target.Tag.Contains('capture'))
}
function Invoke-ModalCommand($Target,[string]$Command){
    $focus=[Windows.Input.Keyboard]::FocusedElement
    if($Command -eq 'Back'){$Target.Close();return}
    if($Command -eq 'Confirm'){
        if($focus -is [Windows.Controls.CheckBox]){$focus.IsChecked=-not $focus.IsChecked;return}
        if($focus -is [Windows.Controls.Button] -and $focus.IsEnabled){$focus.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent));return}
        [void]$Target.MoveFocus([Windows.Input.TraversalRequest]::new([Windows.Input.FocusNavigationDirection]::Next));return
    }
    if($Command -in @('Up','Down') -and $focus -is [Windows.Controls.Primitives.Selector]){
        $delta=if($Command -eq 'Up'){-1}else{1};$focus.SelectedIndex=[Math]::Max(0,[Math]::Min($focus.Items.Count-1,$focus.SelectedIndex+$delta));return
    }
    if($Command -in @('Left','Right','Up','Down')){[void]$Target.MoveFocus([Windows.Input.TraversalRequest]::new([Windows.Input.FocusNavigationDirection]::$Command))}
}
function Enable-ModalKeyboard($Dialog){
    $Dialog.Add_PreviewKeyDown({param($sender,$eventArgs)
        $focused=[Windows.Input.Keyboard]::FocusedElement
        if($focused -is [Windows.Controls.TextBox] -or $focused -is [Windows.Controls.ComboBox] -or $focused -is [Windows.Controls.ComboBoxItem]){return}
        $command=switch([string]$eventArgs.Key){Left{'Left'}Right{'Right'}Up{'Up'}Down{'Down'}Return{'Confirm'}Enter{'Confirm'}Escape{'Back'}default{''}}
        if($command){Invoke-ModalCommand $sender $command;$eventArgs.Handled=$true}
    })
}
function Invoke-LauncherCommand([string]$Command){
    $baseOperation=Get-Variable -Name OfficialBaseUpdate -Scope Script -ErrorAction SilentlyContinue
    if($baseOperation -and $baseOperation.Value){return}
    $active=Get-ActiveLauncherWindow
    if(-not $active){return}
    # Nesta janela o controle fornece botoes brutos, nunca comandos da interface.
    if(Test-ControlMappingWindow $active){return}
    if($active -ne $window){Invoke-ModalCommand $active $Command;return}
    if($Command -eq 'VirtualSearch'){
        if($script:LibraryView -ne 'Games'){Enter-Platform 'Todas as plataformas'}
        Show-ControlSearch;return
    }
    $focus=[Windows.Input.Keyboard]::FocusedElement
    $platformNames=@($PlatformFilter.Items)
    if($Command -eq 'Confirm' -and $focus -is [Windows.Controls.Button] -and $focus.Tag -notin $platformNames){
        if($focus.IsEnabled){$focus.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))};return
    }
    if($Command -in @('Left','Right','Up','Down') -and $focus -is [Windows.Controls.Button] -and $focus.Tag -notin $platformNames){
        [void]$focus.MoveFocus([Windows.Input.TraversalRequest]::new([Windows.Input.FocusNavigationDirection]::$Command));return
    }
    if($Command -eq 'Search'){
        if($script:LibraryView -ne 'Games'){Enter-Platform 'Todas as plataformas'}
        [void]$Search.Focus();return
    }
    if($Command -eq 'Actions'){if($focus -is [Windows.Controls.Button] -and $focus.Tag -notin $platformNames){[void]$focus.MoveFocus([Windows.Input.TraversalRequest]::new([Windows.Input.FocusNavigationDirection]::Next))}elseif($script:LibraryView -eq 'Platforms'){[void]$settings.Focus()}else{[void]$GameOptionsButton.Focus()};return}
    if($Command -in @('Back','Platforms')){
        if($script:LibraryView -eq 'Games'){Show-PlatformHome};return
    }
    if($script:LibraryView -eq 'Platforms'){
        $names=@($PlatformFilter.Items)
        if(-not $names.Count){return}
        $index=[Array]::IndexOf($names,$script:NavigationPlatform)
        if($index -lt 0){$index=0}
        if($Command -eq 'Confirm'){Enter-Platform ([string]$names[$index]);return}
        $cols=if($PlatformStrip -is [Windows.Controls.Primitives.UniformGrid]){$PlatformStrip.Columns}else{[Math]::Max(1,[int][Math]::Floor($PlatformScroll.ViewportWidth/196))}
        $index=Get-GridNavigationIndex $index $names.Count $cols $Command
        $script:NavigationPlatform=[string]$names[$index]
        $button=$script:PlatformButtons[$script:NavigationPlatform].Child
        [void]$button.Focus();$button.BringIntoView();Update-PlatformHighlight
        return
    }
    if($Command -eq 'Confirm'){
        if($Play.IsEnabled){$Play.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent))};return
    }
    if($Command -eq 'Details'){if($Details.IsEnabled){Show-GameDetails};return}
    $cols=[Math]::Max(1,[int][Math]::Floor(($Games.ActualWidth-20)/160))
    $index=$Games.SelectedIndex
    if($Command -eq 'PageLeft'){$index=[Math]::Max(0,$index-$cols*3)}
    elseif($Command -eq 'PageRight'){$index=[Math]::Min($Games.Items.Count-1,$index+$cols*3)}
    else{$index=Get-GridNavigationIndex $index $Games.Items.Count $cols $Command}
    if($index -ge 0 -and $Games.Items.Count){$Games.SelectedIndex=$index;$Games.ScrollIntoView($Games.SelectedItem);[void]$Games.SelectedItem.Focus()}
}
function Initialize-LauncherInput {
    if(-not ('CentralInput.Native' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ControllerNative.cs')}
    $script:ControlMap=Read-ControlMap
    $script:LauncherFullscreen=$false
    $script:LauncherNormalWindow=$null
    $script:NavigationPlatform='Todas as plataformas'
    $script:PadPrevious=@{};$script:PadDevice='';$script:PadArmed=$false;$script:PadDirection='';$script:PadRepeatAt=[DateTime]::MinValue;$script:SelectAt=$null
    $script:InputHint=New-Object Windows.Controls.TextBlock
    $controlButton=New-Object Windows.Controls.Button;$controlButton.Content='Configurar controle';$controlButton.HorizontalAlignment='Left';$controlButton.Margin='8,0,8,12'
    [Windows.Controls.DockPanel]::SetDock($controlButton,'Top');$PlatformHome.Children.Insert(2,$controlButton)
    $controlButton.Add_Click({Show-ControlSettings})
    $InputHint.Text='Setas: navegar  |  Enter: confirmar/jogar  |  Esc: voltar  |  D: detalhes  |  F: buscar  |  Tab: botoes'
    $InputHint.Margin='18,8,18,8';$InputHint.Foreground='#BDCEBF';$InputHint.FontSize=12
    $InputHint.TextWrapping='Wrap'
    [Windows.Controls.DockPanel]::SetDock($InputHint,'Bottom');$window.Content.Children.Insert(0,$InputHint)
    $window.Add_ContentRendered({Show-PlatformHome;[void]$window.Focus();if($script:PlatformButtons.ContainsKey($script:NavigationPlatform)){[void]$script:PlatformButtons[$script:NavigationPlatform].Child.Focus()}})
    $window.Add_PreviewKeyDown({param($sender,$e)
        if($e.Key -eq 'F11'){
            if(-not $e.IsRepeat){Toggle-LauncherFullscreen}
            $e.Handled=$true;return
        }
        $focus=[Windows.Input.Keyboard]::FocusedElement
        if($focus -is [Windows.Controls.TextBox]){
            if($e.Key -eq 'Escape'){[void]$Games.Focus();$e.Handled=$true}
            elseif($e.Key -eq 'Down' -and $focus -eq $Search -and $Games.SelectedItem){if($script:SearchTimer -and $script:SearchTimer.IsEnabled){$script:SearchTimer.Stop();Refresh-List};if($Games.SelectedItem){[void]$Games.SelectedItem.Focus()};$e.Handled=$true}
            return
        }
        $command=switch([string]$e.Key){Left{'Left'}Right{'Right'}Up{'Up'}Down{'Down'}Return{'Confirm'}Enter{'Confirm'}Escape{'Back'}D{'Details'}F{'Search'}PageUp{'PageLeft'}PageDown{'PageRight'}default{''}}
        if(-not $command){return}
        if($command -eq 'Confirm' -and $focus -is [Windows.Controls.Button] -and $focus.Tag -notin @($PlatformFilter.Items)){return}
        if($e.IsRepeat -and $command -notin @('Left','Right','Up','Down')){$e.Handled=$true;return}
        Invoke-LauncherCommand $command;$e.Handled=$true
    })
    $script:InputTimer=New-Object Windows.Threading.DispatcherTimer
    $InputTimer.Interval=[TimeSpan]::FromMilliseconds(50)
    $InputTimer.Add_Tick({
        try{
            $pad=[CentralInput.Native]::Poll()
            $hint='Setas/controle: navegar | Enter/A/Start: confirmar | Esc/B: voltar | D/X: detalhes | F/Select+Y: buscar'
            $hint+=' | '+$(if($pad.Device){$pad.Device}else{'Controle nao conectado'})
            if($InputHint.Text -ne $hint){$InputHint.Text=$hint}
            $active=Get-ActiveLauncherWindow
            if(Test-ControlMappingWindow $active){
                $script:PadArmed=$false;$script:PadPrevious=@{};$script:PadDirection='';$script:SelectAt=$null
                return
            }
            if(-not $active -or -not $pad.Device -or $pad.Device -ne $script:PadDevice){$script:PadArmed=$false;$script:PadPrevious=@{};$script:PadDirection='';$script:PadDevice=$pad.Device;$script:SelectAt=$null;return}
            $buttons=Convert-PadButtons $pad $script:ControlMap
            if(-not $script:PadArmed){if(-not $pad.Direction -and $pad.Buttons -eq 0){$script:PadArmed=$true};return}
            $now=[DateTime]::UtcNow
            $edge=@{};foreach($key in $buttons.Keys){$edge[$key]=$buttons[$key] -and (-not $script:PadPrevious.ContainsKey($key) -or -not $script:PadPrevious[$key])}
            $script:PadPrevious=$buttons
            if($pad.Direction){if($pad.Direction -ne $script:PadDirection){$script:PadRepeatAt=$now.AddMilliseconds(400);Invoke-LauncherCommand $pad.Direction}elseif($now -ge $script:PadRepeatAt){$script:PadRepeatAt=$now.AddMilliseconds(130);Invoke-LauncherCommand $pad.Direction}}
            $script:PadDirection=$pad.Direction
            if($buttons.Actions -and $buttons.Platforms){if($edge.Actions -or $edge.Platforms){Invoke-LauncherCommand 'VirtualSearch'};$script:SelectAt=$null;return}
            if($edge.Actions){$script:SelectAt=$now}
            if($null -ne $script:SelectAt -and ($now-$script:SelectAt).TotalMilliseconds -gt 220){$script:SelectAt=$null;Invoke-LauncherCommand 'Actions';return}
            foreach($key in 'Back','Confirm','Start','Details','Platforms','PageLeft','PageRight'){
                if($edge[$key]){Invoke-LauncherCommand $(if($key -eq 'Start'){'Confirm'}else{$key});break}
            }
        }catch{$InputHint.Text='Falha no controle: '+$_.Exception.Message}
    })
    if(-not $Verify){$InputTimer.Start()}
    $window.Add_Closed({$InputTimer.Stop()})
}
function Toggle-LauncherFullscreen {
    if(-not $script:LauncherFullscreen){
        $bounds=if($window.WindowState -eq 'Normal'){[Windows.Rect]::new($window.Left,$window.Top,$window.Width,$window.Height)}else{$window.RestoreBounds}
        $script:LauncherNormalWindow=@{Bounds=$bounds;State=$window.WindowState;Style=$window.WindowStyle;Resize=$window.ResizeMode}
        $window.WindowState='Normal'
        $window.WindowStyle='None';$window.ResizeMode='NoResize'
        $window.WindowState='Maximized'
        $script:LauncherFullscreen=$true
    }else{
        $saved=$script:LauncherNormalWindow
        $window.WindowState='Normal';$window.WindowStyle=$saved.Style;$window.ResizeMode=$saved.Resize
        $window.Left=$saved.Bounds.Left;$window.Top=$saved.Bounds.Top;$window.Width=$saved.Bounds.Width;$window.Height=$saved.Bounds.Height
        $window.WindowState=$saved.State
        $script:LauncherFullscreen=$false
    }
}
function Show-ControlSearch {
    $dialog=New-Object Windows.Window;$dialog.Title='Buscar jogos';$dialog.Owner=$window;$dialog.Width=650;$dialog.Height=470;$dialog.WindowStartupLocation='CenterOwner';$dialog.Background='#192226';$dialog.Foreground='White'
    $panel=New-Object Windows.Controls.StackPanel;$panel.Margin='20'
    $display=New-Object Windows.Controls.TextBox;$display.Text=$Search.Text;$display.IsReadOnly=$true;$display.FontSize=22;$display.Padding='8';$display.Focusable=$false;[void]$panel.Children.Add($display)
    $keys=New-Object Windows.Controls.Primitives.UniformGrid;$keys.Columns=10;$keys.Margin='0,16,0,12'
    $first=$null
    foreach($letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.ToCharArray()){
        $key=New-Object Windows.Controls.Button;$key.Content=[string]$letter;$key.Margin='3';$key.Height=42;$key.FontSize=17
        $key.Add_Click({param($sender,$eventArgs) $display.Text+=[string]$sender.Content})
        [void]$keys.Children.Add($key);if(-not $first){$first=$key}
    }
    [void]$panel.Children.Add($keys)
    $actions=New-Object Windows.Controls.Primitives.UniformGrid;$actions.Columns=4
    foreach($text in 'Espaco','Apagar','Limpar','Buscar'){
        $key=New-Object Windows.Controls.Button;$key.Content=$text;$key.Margin='3';$key.Height=42
        $key.Add_Click({param($sender,$eventArgs) switch([string]$sender.Content){Espaco{$display.Text+=' '}Apagar{if($display.Text.Length){$display.Text=$display.Text.Substring(0,$display.Text.Length-1)}}Limpar{$display.Text=''}Buscar{$Search.Text=$display.Text;$dialog.DialogResult=$true}}})
        [void]$actions.Children.Add($key)
    }
    [void]$panel.Children.Add($actions)
    $hint=New-Object Windows.Controls.TextBlock;$hint.Text='Direcional: escolher letra | A: confirmar | B: cancelar';$hint.Margin='0,14,0,0';[void]$panel.Children.Add($hint)
    $dialog.Content=$panel;$dialog.Add_ContentRendered({[void]$first.Focus()});[void]$dialog.ShowDialog()
    if($Games.SelectedItem){[void]$Games.SelectedItem.Focus()}
}
function Show-ControlSettings {
    $dialog=New-Object Windows.Window;$dialog.Title='Controle do launcher';if(-not $Verify){$dialog.Owner=$window};$dialog.Width=860;$dialog.Height=660;$dialog.MinWidth=760;$dialog.MinHeight=520;$dialog.WindowStartupLocation='CenterOwner';$dialog.Background='#1B2428';$dialog.Foreground='White';$dialog.FontFamily='Segoe UI'
    Enable-ModalKeyboard $dialog
    $layout=New-Object Windows.Controls.Grid;$layout.Margin='20'
    $column=New-Object Windows.Controls.ColumnDefinition;$column.Width=[Windows.GridLength]::new(310);[void]$layout.ColumnDefinitions.Add($column)
    [void]$layout.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
    $previewPanel=New-Object Windows.Controls.StackPanel;$previewPanel.Margin='0,0,22,0';[void]$layout.Children.Add($previewPanel)
    Add-ControllerPreview $dialog $previewPanel
    $panel=New-Object Windows.Controls.StackPanel
    $help=New-Object Windows.Controls.TextBlock;$help.Text='USB: selecione o campo da acao, solte os botoes e pressione o desejado. Tambem pode digitar o numero (1 a 32). Botoes ja usados trocam de acao. Xbox usa A/B/X/Y e Start automaticamente.';$help.TextWrapping='Wrap';$help.Margin='0,0,0,12';[void]$panel.Children.Add($help)
    $labels=@{Confirm='Confirmar / Jogar';Back='Voltar';Details='Detalhes';Platforms='Plataformas (Y)';Actions='Acoes (Select)';Start='Start';PageLeft='Pagina anterior (L)';PageRight='Proxima pagina (R)'}
    $fields=@{}
    $capture=@{target=$null;armed=$false;fields=$fields;hint=$help}
    $dialog.Tag.capture=$capture
    foreach($key in 'Confirm','Back','Details','Platforms','Actions','Start','PageLeft','PageRight'){
        $row=New-Object Windows.Controls.DockPanel;$row.Margin='0,4,0,4';$label=New-Object Windows.Controls.TextBlock;$label.Text=$labels[$key];$label.Width=230;[void]$row.Children.Add($label)
        $box=New-Object Windows.Controls.TextBox;$box.Text=[string]$script:ControlMap[$key];$box.Padding='6';$fields[$key]=$box;[void]$row.Children.Add($box);[void]$panel.Children.Add($row)
        $box.Add_GotKeyboardFocus({param($sender,$eventArgs) $capture.target=$sender;$capture.armed=$false;$capture.hint.Text='Solte os botoes e pressione o botao para esta acao.';$sender.SelectAll()}.GetNewClosure())
        $box.Add_LostKeyboardFocus({param($sender,$eventArgs) if($capture.target -eq $sender){$capture.target=$null;$capture.armed=$false}}.GetNewClosure())
    }
    $errorLabel=New-Object Windows.Controls.TextBlock;$errorLabel.Foreground='LightSalmon';$errorLabel.TextWrapping='Wrap';[void]$panel.Children.Add($errorLabel)
    $save=New-Object Windows.Controls.Button;$save.Content='Salvar controle';$save.Padding='12,8';$save.Margin='0,16,0,0'
    $save.Add_Click({try{
        $map=@{};foreach($key in $fields.Keys){$number=0;if(-not [int]::TryParse($fields[$key].Text,[ref]$number) -or $number -lt 1 -or $number -gt 32){throw 'Use numeros de 1 a 32.'};$map[$key]=$number}
        if(@($map.Values|Sort-Object -Unique).Count -ne $map.Count){throw 'Cada acao precisa de um botao diferente.'}
        $file=Join-Path $script:AppRoot 'Dados\controle.json';New-Item -ItemType Directory -Force -Path (Split-Path $file -Parent)|Out-Null
        [IO.File]::WriteAllText(($file+'.tmp'),($map|ConvertTo-Json),[Text.UTF8Encoding]::new($true))
        if([IO.File]::Exists($file)){[IO.File]::Replace(($file+'.tmp'),$file,($file+'.bak'))}else{[IO.File]::Move(($file+'.tmp'),$file)}
        $script:ControlMap=$map;$dialog.Close()
    }catch{$errorLabel.Text=$_.Exception.Message}})
    [void]$panel.Children.Add($save);$scroll=New-Object Windows.Controls.ScrollViewer;$scroll.Content=$panel;$scroll.VerticalScrollBarVisibility='Auto';[Windows.Controls.Grid]::SetColumn($scroll,1);[void]$layout.Children.Add($scroll);$dialog.Content=$layout
    if($Verify){return $dialog}
    [void]$dialog.ShowDialog()
}
