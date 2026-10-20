function Get-ControllerVisualStyle($State) {
    if(-not $State.Device){return 'Generic'}
    if($State.Kind -eq 'XInput' -or $State.Device -match '(?i)\bxbox\b'){return 'Xbox'}
    if($State.Device -match '(?i)\bps2\b|dualshock\s*2'){return 'PS2'}
    if($State.Device -match '(?i)dualshock|dualsense|sony|playstation'){return 'Sony'}
    if($State.Device -match '(?i)\bsnes\b|super nintendo'){return 'SNES'}
    if($State.Device -match '(?i)mega.?drive|genesis'){return 'MegaDrive'}
    return 'Generic'
}
function New-ControllerIllustration([string]$Style) {
    if($Style -notin @('Xbox','Sony','PS2','SNES','MegaDrive','Generic')){$Style='Generic'}
    $path=Join-Path $script:AppRoot ('Recursos\Controles\'+$Style+'.jpg')
    $card=New-Object Windows.Controls.Border;$card.Background='White';$card.CornerRadius='8';$card.Padding='10';$card.Margin='0,12,0,8'
    if(Test-Path -LiteralPath $path){
        $image=New-Object Windows.Controls.Image;$image.Height=215;$image.Stretch='Uniform';$image.StretchDirection='DownOnly'
        $bitmap=New-Object Windows.Media.Imaging.BitmapImage;$bitmap.BeginInit();$bitmap.CacheOption='OnLoad';$bitmap.DecodePixelWidth=640;$bitmap.UriSource=[Uri]$path;$bitmap.EndInit();$bitmap.Freeze();$image.Source=$bitmap;$card.Child=$image
    }else{
        $text=New-Object Windows.Controls.TextBlock;$text.Text='Foto de referencia indisponivel';$text.Foreground='Black';$text.TextWrapping='Wrap';$card.Child=$text
    }
    return $card
}
function Update-ControlMappingCapture($Ui,$State) {
    if(-not $Ui.ContainsKey('capture') -or -not $Ui.capture.target){return}
    $capture=$Ui.capture
    if(-not $State.Device){$capture.armed=$false;return}
    if($State.Kind -eq 'XInput'){$capture.hint.Text='Xbox usa o mapeamento automatico A/B/X/Y. Estes campos sao para controles USB/WinMM.';return}
    if([uint32]$State.Buttons -eq 0){$capture.armed=$true;return}
    if(-not $capture.armed){return}
    $pressed=@(0..31 | Where-Object {([uint32]$State.Buttons -band ([uint32]1 -shl $_)) -ne 0})
    if($pressed.Count -ne 1){$capture.hint.Text='Pressione apenas um botao por vez.';return}
    $box=$capture.target;$number=[string]($pressed[0]+1);$old=$box.Text
    # Trocar atribuicoes evita duplicidade quando o usuario remapeia dois botoes.
    foreach($other in $capture.fields.Values){if($other -ne $box -and $other.Text -eq $number){$other.Text=$old}}
    $box.Text=$number;$box.SelectAll();$capture.armed=$false
    $capture.hint.Text='Botao '+$number+' atribuido. Selecione outra acao ou clique em Salvar controle.'
}
function Update-ControllerPreview($Dialog) {
    $ui=$Dialog.Tag;$state=[CentralInput.Native]::Poll()
    Update-ControlMappingCapture $ui $state
    $style=Get-ControllerVisualStyle $state;$connected=[bool]$state.Device
    $ui.status.Text=if($connected){'Conectado: '+$state.Device+' ('+$state.Kind+')'}else{'Nenhum controle conectado'}
    $ui.status.Foreground=if($connected){[Windows.Media.Brushes]::LightGreen}else{[Windows.Media.Brushes]::LightGray}
    $ui.note.Text=if($style -eq 'Generic' -and $connected){'Modelo nao identificado pelo driver. Foto ilustrativa de um controle USB; nao identifica a marca do conectado.'}elseif($connected){'Familia identificada automaticamente pelo driver. Foto de referencia; o modelo fisico pode variar.'}else{'Conecte um controle. A foto e apenas uma referencia visual.'}
    if($ui.current -ne $style){$ui.image.Content=New-ControllerIllustration $style;$ui.current=$style}
    $ui.image.Opacity=if($connected){1.0}else{0.4}
    $pressed=@();for($button=0;$button -lt $(if($state.Kind -eq 'XInput'){16}else{32});$button++){if(($state.Buttons -band ([uint32]1 -shl $button)) -ne 0){$pressed+=($button+1)}}
    $ui.buttons.Text=if($connected){'Botoes (indices do driver): '+$(if($pressed.Count){$pressed -join ', '}else{'nenhum'})+' | Direcional: '+$(if($state.Direction){$state.Direction}else{'neutro'})}else{''}
}
function Add-ControllerPreview($Dialog,$Panel) {
    $ui=@{current=''}
    $ui.status=New-Object Windows.Controls.TextBlock;$ui.status.TextWrapping='Wrap';$ui.status.Margin='0,0,0,8';[void]$Panel.Children.Add($ui.status)
    $ui.image=New-Object Windows.Controls.ContentControl;[void]$Panel.Children.Add($ui.image)
    $ui.note=New-Object Windows.Controls.TextBlock;$ui.note.TextWrapping='Wrap';$ui.note.FontSize=12;$ui.note.Margin='0,6,0,10';[void]$Panel.Children.Add($ui.note)
    $ui.buttons=New-Object Windows.Controls.TextBlock;$ui.buttons.TextWrapping='Wrap';$ui.buttons.FontSize=12;$ui.buttons.Margin='0,0,0,16';[void]$Panel.Children.Add($ui.buttons)
    $credits=New-Object Windows.Controls.TextBlock;$credits.Text='Fotos: Wikimedia Commons. Creditos em Recursos/Controles/CREDITOS.txt';$credits.FontSize=10;$credits.Foreground='#9DB5A4';$credits.TextWrapping='Wrap';[void]$Panel.Children.Add($credits)
    $Dialog.Tag=$ui
    $ui.timer=New-Object Windows.Threading.DispatcherTimer;$ui.timer.Interval=[TimeSpan]::FromMilliseconds(50)
    $ui.timer.Add_Tick({Update-ControllerPreview $Dialog}.GetNewClosure())
    $Dialog.Add_Closed({$Dialog.Tag.timer.Stop()}.GetNewClosure())
    Update-ControllerPreview $Dialog;$ui.timer.Start()
}
