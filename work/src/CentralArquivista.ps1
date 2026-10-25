param([switch]$Verify,[switch]$VerifyClean)
if($VerifyClean){$Verify=$true}
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ProductName='TarginoLauncher - Recompilados by Central Arquivista'
. (Join-Path $PSScriptRoot 'Catalog.ps1')
. (Join-Path $PSScriptRoot 'GameVersions.ps1')
. (Join-Path $PSScriptRoot 'PortablePaths.ps1')
. (Join-Path $PSScriptRoot 'Graphics.ps1')
. (Join-Path $PSScriptRoot 'AdditionalCatalog.ps1')
. (Join-Path $PSScriptRoot 'Input.ps1')
. (Join-Path $PSScriptRoot 'ControllerVisuals.ps1')
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms
if(-not ('TarginoLauncher.WindowIdentity' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'WindowIdentity.cs')}
[TarginoLauncher.WindowIdentity]::Initialize()

$xaml=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'MainWindow.xaml'))
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.Title=$script:ProductName
$script:OperationProgress = New-Object Windows.Controls.ProgressBar
$OperationProgress.Height = 10
$OperationProgress.Margin = '0,10,0,0'
$OperationProgress.Foreground = '#65E843'
$OperationProgress.Background = '#303A3F'
$OperationProgress.BorderThickness = '0'
$OperationProgress.IsIndeterminate = $true
$OperationProgress.Visibility = 'Collapsed'
$window.FindName('Status').Parent.Children.Add($OperationProgress) | Out-Null
$clockTime = $window.FindName('ClockTime')
$clockDate = $window.FindName('ClockDate')
function Update-HeaderClock {
    $now = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, 'E. South America Standard Time')
    $clockTime.Text = $now.ToString('HH:mm')
    $clockDate.Text = $now.ToString('ddd, dd/MM/yyyy', [Globalization.CultureInfo]::GetCultureInfo('pt-BR'))
}
Update-HeaderClock
$clockTimer = New-Object Windows.Threading.DispatcherTimer
$clockTimer.Interval = [TimeSpan]::FromSeconds(1)
$clockTimer.Add_Tick({ Update-HeaderClock })
$clockTimer.Start()
$window.Add_Closed({ $clockTimer.Stop() })
$script:AppRoot = Split-Path $PSScriptRoot -Parent
if(-not $Verify){
    New-Item -ItemType Directory -Force -Path (Join-Path $script:AppRoot 'Dados')|Out-Null
    try{$script:LauncherLock=[IO.File]::Open((Join-Path $script:AppRoot 'Dados\launcher.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
    catch{[void][Windows.MessageBox]::Show('O launcher ja esta aberto nesta pasta.','Central Arquivista');exit}
    $window.Add_Closed({$script:LauncherLock.Dispose()})
}
$script:BaseCheck=$null
$baseUpdateBar=New-Object Windows.Controls.DockPanel
$baseUpdateBar.Margin='18,6,18,6'
[Windows.Controls.DockPanel]::SetDock($baseUpdateBar,'Top');$window.Content.Children.Insert(1,$baseUpdateBar)
$baseCheckButton=New-Object Windows.Controls.Button;$baseCheckButton.Content='Verificar base';$baseCheckButton.FontSize=12;$baseCheckButton.Padding='10,5';$baseCheckButton.Margin='12,0,0,0'
[Windows.Controls.DockPanel]::SetDock($baseCheckButton,'Right');[void]$baseUpdateBar.Children.Add($baseCheckButton)
$script:BaseUpdateText=New-Object Windows.Controls.TextBlock;$BaseUpdateText.Text='Base: aguardando verificacao';$BaseUpdateText.Foreground='#BDCEBF';$BaseUpdateText.VerticalAlignment='Center';$BaseUpdateText.TextWrapping='Wrap'
[void]$baseUpdateBar.Children.Add($BaseUpdateText)
$script:ActiveInstall = $null
. (Join-Path $PSScriptRoot 'DownloadQueue.ps1')
$script:DownloadQueue = New-DownloadQueue
$script:QueueResults = New-Object 'Collections.Generic.List[string]'
$script:QueueUsed = $false
$script:InstallGame = $null
$script:InstallGame = $null
$connectButton = New-Object Windows.Controls.Button
$connectButton.Content = 'Conectar Telegram'
$window.FindName('Reload').Parent.Children.Add($connectButton) | Out-Null
$headerActions = $window.FindName('Reload').Parent
$headerActions.VerticalAlignment = 'Center'
foreach ($headerButton in @($window.FindName('ChooseRoot'), $window.FindName('Reload'), $connectButton)) {
    $headerButton.Height = 40
    $headerButton.MinWidth = 112
    $headerButton.Padding = '14,0'
    $headerButton.Margin = '0,0,10,0'
    $headerButton.VerticalAlignment = 'Center'
    $headerButton.VerticalContentAlignment = 'Center'
    $headerButton.FontSize = 13
}
$connectButton.Margin = '0'
$cancelButton = New-Object Windows.Controls.Button
$cancelButton.Content = 'Cancelar'
$cancelButton.Visibility = 'Collapsed'
$window.FindName('Play').Parent.Children.Add($cancelButton) | Out-Null
function Get-GameRoot($game) {
    if($game.PSObject.Properties['managedRoot'] -and $game.managedRoot){return $game.managedRoot}
    if($game.PSObject.Properties['libraryRoot'] -and $game.libraryRoot){return $game.libraryRoot}
    return $script:GamesRoot
}
function Get-InstallTools {
    $tdl=Join-Path $script:GamesRoot 'Arquivismo\Ferramentas\Tdl\tdl.exe'
    $unrar=Join-Path $script:GamesRoot 'Ferramentas\UnRAR\UnRAR.exe'
    if(-not(Test-Path -LiteralPath $unrar)){$unrar=Join-Path $script:GamesRoot 'Arquivismo\Ferramentas\UnRar\UnRAR.exe'}
    if(-not(Test-Path -LiteralPath $tdl)){throw 'Ferramenta tdl.exe ausente na base do Arquivista selecionada. Selecione uma base completa. O aplicativo Telegram Desktop nao e necessario.'}
    if(-not(Test-Path -LiteralPath $unrar)){throw 'Ferramenta UnRAR ausente na base do Arquivista selecionada. Selecione uma base completa para extrair os jogos.'}
    return @{tdl=$tdl;unrar=$unrar;session=(Join-Path $script:AppRoot 'Dados\Telegram\session.json')}
}
$connectButton.Add_Click({try{
    $tools=Get-InstallTools
    $login=Join-Path $PSScriptRoot 'ConnectTelegram.ps1'
    Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File '+(ConvertTo-WindowsArgument $login)+' -Tool '+(ConvertTo-WindowsArgument $tools.tdl)+' -Session '+(ConvertTo-WindowsArgument $tools.session))
}catch{Set-Status $_.Exception.Message $true}})
$cancelButton.Add_Click({if($script:ActiveInstall){[IO.File]::WriteAllText((Join-Path $script:ActiveInstall 'cancel'),'cancel')}})
$script:CoverImage = New-Object Windows.Controls.Image
$CoverImage.Height = 225
$CoverImage.MaxWidth = 300
$CoverImage.HorizontalAlignment = 'Left'
$CoverImage.Stretch = 'Uniform'
$CoverImage.StretchDirection = 'DownOnly'
$detailPanel = $window.FindName('Title').Parent
$detailPanel.Children.Insert(1, $CoverImage)
$script:ScreenshotNotice=New-Object Windows.Controls.TextBlock
$ScreenshotNotice.Text='Captura local indisponivel';$ScreenshotNotice.Foreground='#9DB5A4';$ScreenshotNotice.FontSize=12
$detailPanel.Children.Insert(2,$ScreenshotNotice)
$script:RatingText=New-Object Windows.Controls.TextBlock
$RatingText.TextWrapping='Wrap';$RatingText.Foreground='#A4D997';$RatingText.Margin='0,8,0,0';$RatingText.FontSize=12
$detailPanel.Children.Insert(5,$RatingText)
$script:PlayerInfo=New-Object Windows.Controls.TextBlock
$PlayerInfo.Foreground='#D5E0D7';$PlayerInfo.FontSize=13;$PlayerInfo.Margin='0,8,0,8';$PlayerInfo.TextWrapping='Wrap'
$detailPanel.Children.Insert(4,$PlayerInfo)
$window.FindName('Description').FontSize=14
$window.FindName('Description').MaxHeight=140
$window.FindName('Description').TextTrimming='WordEllipsis'
# Permite acessar todos os dados em janelas menores sem ampliar a captura.
$detailBorder=$detailPanel.Parent
$detailBorder.Child=$null
$detailScroll=New-Object Windows.Controls.ScrollViewer
$detailScroll.VerticalScrollBarVisibility='Auto';$detailScroll.HorizontalScrollBarVisibility='Disabled';$detailScroll.Content=$detailPanel
$detailBorder.Child=$detailScroll
$script:GraphicsButton=New-Object Windows.Controls.Button
$GraphicsButton.Content='Renderizador';$GraphicsButton.FontSize=12;$GraphicsButton.HorizontalAlignment='Left'
[void]$detailPanel.Children.Add($GraphicsButton)
$script:GraphicsInfo=New-Object Windows.Controls.TextBlock
$GraphicsInfo.Foreground='#9DB5A4';$GraphicsInfo.TextWrapping='Wrap';$GraphicsInfo.FontSize=12
[void]$detailPanel.Children.Add($GraphicsInfo)
$script:UpdateButton = New-Object Windows.Controls.Button
$UpdateButton.Content = 'Update'
$window.FindName('Play').Parent.Children.Add($UpdateButton) | Out-Null
foreach ($name in 'ChooseRoot','Reload','Search','Games','Title','Meta','Description','Play','Details','Status') { Set-Variable -Name $name -Value $window.FindName($name) -Scope Script }
$Description.Visibility='Collapsed'
$script:Root = $null; $script:GamesRoot = $null; $script:Catalog = @(); $script:Selected = $null
$Games.DisplayMemberPath = 'title'
$Games.Background = 'Transparent'
$Games.BorderThickness = '0'
$script:PlatformFilter=New-Object Windows.Controls.ComboBox
$script:PlatformButtons=@{}
$script:LibraryView='Platforms'
$script:PlatformPositions=@{}
$platformNavigation=New-Object Windows.Controls.DockPanel
$platformNavigation.Margin='0,6,0,8'
$script:GameListPanel=$Search.Parent
$script:LibraryGrid=$GameListPanel.Parent
$script:PlatformHome=New-Object Windows.Controls.DockPanel
[Windows.Controls.Grid]::SetColumnSpan($PlatformHome,2)
$homeHeading=New-Object Windows.Controls.TextBlock;$homeHeading.Text='ESCOLHA UMA PLATAFORMA';$homeHeading.FontSize=23;$homeHeading.Foreground='White';$homeHeading.Margin='8,4,8,16'
[Windows.Controls.DockPanel]::SetDock($homeHeading,'Top');[void]$PlatformHome.Children.Add($homeHeading)
$homeAdd=New-Object Windows.Controls.Button;$homeAdd.Content='+ Adicionar jogo';$homeAdd.HorizontalAlignment='Left';$homeAdd.Margin='8,0,8,12';$homeAdd.Add_Click({Open-AdditionalGameEditor})
[Windows.Controls.DockPanel]::SetDock($homeAdd,'Top');[void]$PlatformHome.Children.Add($homeAdd)
[void]$PlatformHome.Children.Add($platformNavigation)
[void]$LibraryGrid.Children.Add($PlatformHome)
$script:BackToPlatforms=New-Object Windows.Controls.Button;$BackToPlatforms.Content='‹ Plataformas';$BackToPlatforms.HorizontalAlignment='Left';$BackToPlatforms.Margin='4,0,4,10';$BackToPlatforms.Add_Click({Show-PlatformHome})
[Windows.Controls.DockPanel]::SetDock($BackToPlatforms,'Top');$GameListPanel.Children.Insert(0,$BackToPlatforms)
$script:PlatformScroll=New-Object Windows.Controls.ScrollViewer
$PlatformScroll.HorizontalScrollBarVisibility='Disabled';$PlatformScroll.VerticalScrollBarVisibility='Auto'
$script:PlatformStrip=New-Object Windows.Controls.Primitives.UniformGrid;$PlatformStrip.Columns=5
$PlatformScroll.HorizontalContentAlignment='Stretch'
$PlatformScroll.Content=$PlatformStrip;[void]$platformNavigation.Children.Add($PlatformScroll)
$script:SuppressRefresh=$false;$script:ThumbCache=@{}
$PlatformFilter.Add_SelectionChanged({Update-PlatformHighlight;if(-not $script:SuppressRefresh){Refresh-List}})
function Show-PlatformHome {
    if($script:Selected -and $PlatformFilter.SelectedItem){$script:PlatformPositions[[string]$PlatformFilter.SelectedItem]=$script:Selected.id}
    $script:LibraryView='Platforms'
    if($PlatformFilter.SelectedItem){$script:NavigationPlatform=[string]$PlatformFilter.SelectedItem}
    $PlatformHome.Visibility='Visible';$GameListPanel.Visibility='Collapsed';$detailBorder.Visibility='Collapsed'
    if($PlatformFilter.SelectedItem -and $script:PlatformButtons.ContainsKey([string]$PlatformFilter.SelectedItem)){[void]$script:PlatformButtons[[string]$PlatformFilter.SelectedItem].Child.Focus()}
    Update-PlatformHighlight
}
function Enter-Platform([string]$Name) {
    $Search.Text=''
    $PlatformFilter.SelectedItem=$Name
    $script:LibraryView='Games'
    $PlatformHome.Visibility='Collapsed';$GameListPanel.Visibility='Visible';$detailBorder.Visibility='Visible'
    $BackToPlatforms.Content='‹ Plataformas  /  '+$(if($Name -eq 'Todas as plataformas'){'Todos os jogos'}else{$Name})
    if($script:PlatformPositions.ContainsKey($Name)){
        foreach($tile in $Games.Items){if($tile.Tag.id -eq $script:PlatformPositions[$Name]){$Games.SelectedItem=$tile;$Games.ScrollIntoView($tile);break}}
    }
    if($Games.SelectedItem){[void]$Games.SelectedItem.Focus()}else{[void]$Games.Focus()}
    Update-PlatformHighlight
}
function Update-PlatformHighlight {
    foreach($name in $script:PlatformButtons.Keys){
        $card=$script:PlatformButtons[$name]
        $activeName=if($script:LibraryView -eq 'Platforms'){$script:NavigationPlatform}else{[string]$PlatformFilter.SelectedItem}
        $card.BorderBrush=if($name -eq $activeName){'#65E843'}else{'#46564E'}
        $card.Child.Background=if($name -eq $activeName){'#245C37'}else{'#25322C'}
        $card.Background=$card.Child.Background
    }
}
function Build-PlatformButtons {
    $PlatformStrip.Children.Clear();$script:PlatformButtons=@{}
    $logos=@{'Todas as plataformas'='auto-allgames';'Arcade'='arcade';'Game Boy'='gb';'Game Boy Advance'='gba';'Game Boy Color'='gbc';'GameCube'='gc';'Nintendo 64'='n64';'Nintendo 64DD'='n64dd';'Nintendo Switch'='switch';'Nintendo'='nes';'Super Nintendo'='snes';'Wii'='wii';'PlayStation'='psx';'PlayStation 2'='ps2';'PlayStation 3'='ps3';'PlayStation 4'='ps4';'PlayStation 5'='ps5';'PSP'='psp';'Xbox'='xbox';'Xbox 360'='xbox360';'Xbox One'='xboxone';'PC / Windows'='windows';'PC / origem nao informada'='pc'}
    foreach($name in $PlatformFilter.Items){
        $border=New-Object Windows.Controls.Border;$border.BorderThickness='2';$border.Margin='8';$border.CornerRadius='3'
        $button=New-Object Windows.Controls.Button;$button.HorizontalAlignment='Stretch';$button.VerticalAlignment='Stretch';$button.Margin='0';$button.Padding='12,10';$button.Tag=[string]$name;$button.ToolTip=[string]$name
        $content=New-Object Windows.Controls.StackPanel
        $logoFile=if($logos.ContainsKey([string]$name)){Join-Path $script:AppRoot ('Recursos\Plataformas\'+$logos[[string]$name]+'.png')}else{''}
        if($logoFile -and [IO.File]::Exists($logoFile)){
            $image=New-Object Windows.Controls.Image;$image.Height=54;$image.Width=150;$image.Stretch='Uniform';$image.Source=[Windows.Media.Imaging.BitmapImage]::new([Uri]$logoFile);$image.Margin='0,0,0,12';[void]$content.Children.Add($image)
        }else{
            $wordmark=New-Object Windows.Controls.TextBlock;$wordmark.Text=[string]$name;$wordmark.FontSize=17;$wordmark.FontWeight='SemiBold';$wordmark.Height=41;$wordmark.TextAlignment='Center';$wordmark.TextWrapping='Wrap';[void]$content.Children.Add($wordmark)
        }
        $count=if($name -eq 'Todas as plataformas'){$script:Catalog.Count}else{@($script:Catalog|Where-Object {(Get-OriginPlatform $_) -eq $name}).Count}
        $caption=New-Object Windows.Controls.TextBlock;$caption.Text=$count.ToString()+' jogos';$caption.FontSize=12;$caption.TextAlignment='Center';[void]$content.Children.Add($caption)
        $button.Content=$content
        $button.Add_Click({param($sender,$eventArgs) Enter-Platform ([string]$sender.Tag)})
        $button.Add_GotKeyboardFocus({param($sender,$eventArgs) $script:NavigationPlatform=[string]$sender.Tag;Update-PlatformHighlight})
        $border.Child=$button;$script:PlatformButtons[[string]$name]=$border;[void]$PlatformStrip.Children.Add($border)
    }
    Update-PlatformHighlight
    Update-PlatformLayout
}
function Update-PlatformLayout {
    # ActualWidth e uma reserva fixa evitam usar o viewport antigo durante resize/reload.
    $width=$PlatformScroll.ActualWidth-18
    if($width -lt 100){return}
    $columns=[Math]::Max(1,[int][Math]::Floor(($width-2)/210))
    $PlatformStrip.Columns=$columns
    $rows=[Math]::Max(1,[Math]::Ceiling($PlatformStrip.Children.Count/[double]$columns))
    $cellHeight=[Math]::Min(200,[Math]::Max(148,($PlatformScroll.ActualHeight-2)/$rows))
    $PlatformStrip.Height=$rows*$cellHeight
    foreach($card in $PlatformStrip.Children){$card.Child.Width=[double]::NaN;$card.Child.Height=[double]::NaN}
}
$PlatformScroll.Add_SizeChanged({Update-PlatformLayout})
$PlatformScroll.Add_ScrollChanged({param($sender,$eventArgs) if($eventArgs.ViewportWidthChange -ne 0 -or $eventArgs.ViewportHeightChange -ne 0){Update-PlatformLayout}})
function Get-OriginPlatform($game) {
    $names=@{N64='Nintendo 64';N64DD='Nintendo 64DD';PS1='PlayStation';PS2='PlayStation 2';PS3='PlayStation 3';PS4='PlayStation 4';PS5='PlayStation 5';PSP='PSP';SNES='Super Nintendo';NES='Nintendo';GBA='Game Boy Advance';GB='Game Boy';GBC='Game Boy Color';X360='Xbox 360';XBLA='Xbox 360';XBOX='Xbox';XONE='Xbox One';NS='Nintendo Switch';GC='GameCube';Wii='Wii';Win='PC / Windows';Arcade='Arcade'}
    foreach($match in [regex]::Matches($game.title,'\(([^)]+)\)')){if($names.ContainsKey($match.Groups[1].Value)){return $names[$match.Groups[1].Value]}}
    if($game.originalSystem){return [string]$game.originalSystem}
    return 'PC / origem nao informada'
}

function Set-Status([string]$Text, [bool]$ErrorState = $false) { $Status.Text = $Text; $Status.ToolTip = $(if ($Text) { $Text } else { $null }); $Status.Foreground = if ($ErrorState) { '#FFAA98' } else { '#A4D997' } }
# Miniaturas decodificadas uma vez por capa/estado; o cache e limpo em Load-Catalog.
function Get-TileCover([string]$Path,[bool]$Installed) {
    $key = $Path + '|' + $(if ($Installed) { '1' } else { '0' })
    if ($script:ThumbCache.ContainsKey($key)) { return $script:ThumbCache[$key] }
    $image = $null
    try {
        $thumb = New-Object Windows.Media.Imaging.BitmapImage
        $thumb.BeginInit(); $thumb.CacheOption = 'OnLoad'; $thumb.DecodePixelWidth = 180
        $thumb.UriSource = [Uri]$Path; $thumb.EndInit(); $thumb.Freeze()
        if ($Installed) { $image = $thumb }
        else {
            $gray = New-Object Windows.Media.Imaging.FormatConvertedBitmap
            $gray.BeginInit(); $gray.Source = $thumb
            $gray.DestinationFormat = [Windows.Media.PixelFormats]::Gray8
            $gray.EndInit(); $gray.Freeze()
            $image = $gray
        }
    } catch { }
    $script:ThumbCache[$key] = $image
    return $image
}
function Refresh-List {
    $previousId=if($script:Selected){$script:Selected.id}else{''}
    $Games.Items.Clear(); $needle = $Search.Text.Trim().ToLowerInvariant()
    $platform=[string]$PlatformFilter.SelectedItem
    foreach ($g in ($script:Catalog | Where-Object { ([string]::IsNullOrWhiteSpace($needle) -or ([string]$_.title).ToLowerInvariant().Contains($needle)) -and (-not $platform -or $platform -eq 'Todas as plataformas' -or (Get-OriginPlatform $_) -eq $platform) } | Sort-Object title)) {
        $item = New-Object Windows.Controls.ListBoxItem
        $item.Tag = $g
        $tileData = New-Object 'Collections.Generic.Dictionary[string,object]'
        $tileData['title'] = $g.title
        $tileData['cover'] = $null
        $installed = $false
        try { $installed = [IO.File]::Exists((Resolve-CatalogPath (Get-GameRoot $g) $g.executable)) } catch { }
        if ($g.cover -and [IO.File]::Exists($g.cover)) { $tileData['cover'] = Get-TileCover ([string]$g.cover) $installed }
        $item.DataContext = $tileData
        [void]$Games.Items.Add($item)
        [void]$item.ApplyTemplate()
        $visual = [Windows.Media.VisualTreeHelper]::GetChild($item,0)
        $visual.Child.Children[0].Source = $tileData['cover']
        $visual.Child.Children[0].Opacity = if ($installed) { 1.0 } else { 0.55 }
        $visual.Child.Children[1].Child.Text = $g.title
        $visual.Child.Children[1].Child.Foreground = if ($installed) { [Windows.Media.Brushes]::White } else { [Windows.Media.Brushes]::Silver }
    }
    if(-not $script:ActiveInstall){$Status.Text=('{0} de {1} jogos' -f $Games.Items.Count,$script:Catalog.Count)}
    if($Games.Items.Count){
        $keep=@($Games.Items|Where-Object {$_.Tag.id -eq $previousId})
        if($keep.Count){$Games.SelectedItem=$keep[0]}else{$Games.SelectedIndex=0}
    }else{
        $Title.Text='Nenhum jogo encontrado';$Description.Text='Ajuste a busca ou escolha outra plataforma.';$CoverImage.Source=$null;$Play.IsEnabled=$false;$Details.IsEnabled=$false
    }
}
function Load-Catalog {
    if (-not $script:Root) { Set-Status 'Escolha uma pasta de biblioteca para começar.'; return }
    $script:JsonRecoveredFromBackup=$null;$script:ThumbCache=@{}
    $newFile = Join-Path $script:Root 'catalog.json'
    $legacyFile = Join-Path $script:Root 'catalogo.json'
    if (-not (Test-Path -LiteralPath $legacyFile)) { $legacyFile = Join-Path $script:Root 'Dados\catalogo.json' }
    if (-not (Test-Path -LiteralPath $legacyFile)) { $legacyFile = Join-Path $script:Root 'Arquivismo\Dados\catalogo.json' }
    try {
        if (Test-Path -LiteralPath $newFile) { $data = Read-CentralJson $newFile; $script:GamesRoot = $script:Root; $script:Catalog = @($data.games) }
        elseif (Test-Path -LiteralPath $legacyFile) {
            $legacyRoot = Split-Path (Split-Path (Split-Path $legacyFile -Parent) -Parent) -Parent
            $old = Read-CentralJson $legacyFile
            $script:GamesRoot = $legacyRoot
            $script:Catalog = @($old | ForEach-Object {
                Convert-BaseCatalogEntry $_
            })
            foreach ($entry in $script:Catalog) {
                $original = $old | Where-Object { $_.Id -eq $entry.id } | Select-Object -First 1
                $entry | Add-Member -NotePropertyName downloadLink -NotePropertyValue (Get-OptionalCatalogText $original 'Link')
                foreach ($extension in '.jpg','.png','.jpeg') {
                    $candidate = Join-Path $legacyRoot ('Arquivismo\Capas\' + $entry.title + $extension)
                    if (Test-Path -LiteralPath $candidate) { $entry.cover = $candidate; break }
                }
                foreach ($extension in '.jpg','.png','.jpeg','.bmp') {
                    $candidate = Join-Path $legacyRoot ('Arquivismo\Imagens\' + $entry.title + $extension)
                    if (Test-Path -LiteralPath $candidate) { $entry.screenshot = $candidate; break }
                }
                if((Get-OptionalCatalogText $original 'Shot')){
                    try{$candidate=Resolve-CatalogPath $legacyRoot (Get-OptionalCatalogText $original 'Shot');if([IO.File]::Exists($candidate)){$entry.screenshot=$candidate}}catch{}
                }
            }
        } else { $script:Catalog = @(); Refresh-List; Set-Status "Catálogo não encontrado. Selecione a instalação do Central Arquivista ou sua pasta Dados." $true; return }
        $overrideFile = Join-Path $PSScriptRoot '..\Dados\executaveis.json'
        if (Test-Path -LiteralPath $overrideFile) {
            $overrides = Read-CentralJson $overrideFile
            foreach ($entry in $script:Catalog) {
                foreach ($fix in $overrides) {
                    if ($entry.executable -ieq $fix.previousExecutable) {
                        $entry.executable = $fix.executable
                        $entry.workingDirectory = Split-Path $fix.executable -Parent
                    }
                }
            }
        }
        $installedFile=Join-Path $script:AppRoot 'Dados\instalados.json'
        [void](Repair-ManagedInstallPaths $script:AppRoot)
        Repair-ManagedGameVersions $script:AppRoot
        $additional=@(Read-AdditionalGames $script:AppRoot)
        foreach($extra in $additional){
            $full=Resolve-CatalogPath $extra.libraryRoot $extra.executable
            $same=@($script:Catalog|Where-Object {try{(Resolve-CatalogPath $script:GamesRoot $_.executable) -ieq $full}catch{$false}})
            if($same.Count -eq 0){$script:Catalog+=@($extra)}
        }
        if(Test-Path -LiteralPath $installedFile){
            $saved=Read-CentralJsonOrBackup $installedFile
            foreach($game in $script:Catalog){
                $prop=$saved.PSObject.Properties[$game.id]
                if($prop){$record=$prop.Value;$game.version=$record.version;$game.executable=$record.executable;$game.workingDirectory=Split-Path $record.executable -Parent;if(-not $game.workingDirectory){$game.workingDirectory='.'};$game|Add-Member -NotePropertyName managedRoot -NotePropertyValue $record.root -Force;$game|Add-Member -NotePropertyName versionVerified -NotePropertyValue ((Get-OptionalCatalogText $record 'versionSource') -eq 'arquivista-message') -Force}
            }
        }
        $originalVersions=Join-Path $script:GamesRoot 'Arquivismo\Cache\versoes_jogos.json'
        if(Test-Path -LiteralPath $originalVersions){
            $versionMap=Read-CentralJson $originalVersions
            foreach($game in $script:Catalog){if(-not $game.PSObject.Properties['managedRoot']){$prop=$versionMap.PSObject.Properties[$game.id];if($prop){$game.version=if($prop.Value -is [string]){$prop.Value}else{[string]$prop.Value.Ver}}}}
        }
        $acervoVersions=Read-ArquivistaAcervoVersions $script:GamesRoot
        foreach($game in $script:Catalog){
            $available='';$checked=''
            if($acervoVersions.ContainsKey($game.id)){$available=$acervoVersions[$game.id].version;$checked=$acervoVersions[$game.id].checked}
            $game|Add-Member -NotePropertyName availableVersion -NotePropertyValue $available -Force
            $game|Add-Member -NotePropertyName versionChecked -NotePropertyValue $checked -Force
        }
        $previousPlatform=[string]$PlatformFilter.SelectedItem
        $script:SuppressRefresh=$true
        try{
        $PlatformFilter.Items.Clear();[void]$PlatformFilter.Items.Add('Todas as plataformas')
        foreach($name in @($script:Catalog|ForEach-Object {Get-OriginPlatform $_}|Sort-Object -Unique)){[void]$PlatformFilter.Items.Add($name)}
        if($previousPlatform -and $PlatformFilter.Items.Contains($previousPlatform)){$PlatformFilter.SelectedItem=$previousPlatform}else{$PlatformFilter.SelectedIndex=0}
        }finally{$script:SuppressRefresh=$false}
        Build-PlatformButtons
        Refresh-List; Set-Status "$($script:Catalog.Count) jogo(s) carregado(s)."
        if($script:JsonRecoveredFromBackup){Set-Status ('Aviso: '+[IO.Path]::GetFileName($script:JsonRecoveredFromBackup)+' estava corrompido; foi usada a copia de seguranca.') $true;$script:JsonRecoveredFromBackup=$null}
        $homeHeading.Text='ESCOLHA UMA PLATAFORMA'
        if ($Games.Items.Count -gt 0) { $Games.SelectedIndex = 0 }
        if(-not $Verify){Start-BaseUpdateCheck}
    } catch { Set-Status $_.Exception.Message $true; $homeHeading.Text='Falha ao carregar biblioteca: '+$_.Exception.Message }
}
$ChooseRoot.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description='Selecione a raiz do Central Arquivista original (a pasta que contem Arquivismo e Jogos).'
    if ($dialog.ShowDialog() -eq 'OK') {
        $chosen=$dialog.SelectedPath
        if(-not(Test-Path -LiteralPath (Join-Path $chosen 'Arquivismo\Dados\catalogo.json')) -and -not(Test-Path -LiteralPath (Join-Path $chosen 'catalog.json'))){[void][Windows.MessageBox]::Show('Selecione a raiz da biblioteca, e nao a pasta Dados.');return}
        $script:Root=$chosen;Load-Catalog
        $file=Join-Path $script:AppRoot 'Dados\origem.json'
        New-Item -ItemType Directory -Force -Path (Split-Path $file -Parent)|Out-Null
        [IO.File]::WriteAllText(($file+'.tmp'),(@{root=$chosen}|ConvertTo-Json),[Text.UTF8Encoding]::new($true))
        Move-Item -LiteralPath ($file+'.tmp') -Destination $file -Force
        $homeHeading.Text='ESCOLHA UMA PLATAFORMA'
    }
})
$Reload.Add_Click({ Load-Catalog })
# Digitacao do usuario espera uma pausa; mudancas feitas pelo programa (trocar plataforma, busca por controle) atualizam na hora.
$script:SearchTimer=New-Object Windows.Threading.DispatcherTimer;$SearchTimer.Interval=[TimeSpan]::FromMilliseconds(250)
$SearchTimer.Add_Tick({$SearchTimer.Stop();Refresh-List})
$Search.Add_TextChanged({$SearchTimer.Stop();if($Search.IsKeyboardFocused){$SearchTimer.Start()}else{Refresh-List}})
$window.Add_Closed({$SearchTimer.Stop()})
$addButton=New-Object Windows.Controls.Button
$addButton.Content='+ Adicionar jogo';$addButton.FontSize=12;$addButton.HorizontalAlignment='Left';$addButton.Margin='4,6,4,6'
[Windows.Controls.DockPanel]::SetDock($addButton,'Top')
$Search.Parent.Children.Insert(1,$addButton)
$editButton=New-Object Windows.Controls.Button
$editButton.Content='Editar jogo adicional';$editButton.FontSize=12;$editButton.HorizontalAlignment='Left'
[void]$detailPanel.Children.Add($editButton)
function Open-AdditionalGameEditor($Existing=$null) {
    $dialog=New-Object Windows.Window;$dialog.Title='Adicionar jogo ao nosso launcher';$dialog.Owner=$window;$dialog.Width=620;$dialog.Height=690;$dialog.WindowStartupLocation='CenterOwner'
    if($Existing){$dialog.Title='Editar jogo adicional'}
    $stack=New-Object Windows.Controls.StackPanel;$stack.Margin='20'
    $hint=New-Object Windows.Controls.TextBlock;$hint.Text='Este cadastro fica no catalogo complementar do launcher.';$hint.Margin='0,0,0,14';[void]$stack.Children.Add($hint)
    $fields=@{}
    foreach($spec in @(@('title','Nome do jogo'),@('exe','Executavel (.exe)'),@('working','Pasta de trabalho (vazio = pasta do executavel)'),@('cover','Capa local (opcional)'),@('screenshot','Captura local (opcional)'),@('version','Versao instalada (opcional)'),@('download','Link de download (opcional)'),@('description','Descricao (opcional)'),@('arguments','Argumentos: um por linha (opcional)'))){
        $label=New-Object Windows.Controls.TextBlock;$label.Text=$spec[1];$label.Margin='0,8,0,4';[void]$stack.Children.Add($label)
        $row=New-Object Windows.Controls.DockPanel
        $box=New-Object Windows.Controls.TextBox;$box.Padding='6';$fields[$spec[0]]=$box
        if($spec[0] -in @('exe','cover','screenshot')){
            $browse=New-Object Windows.Controls.Button;$browse.Content='Procurar...';$browse.Margin='8,0,0,0';$browse.Padding='8,3';[Windows.Controls.DockPanel]::SetDock($browse,'Right')
            $filter=if($spec[0] -eq 'exe'){'Executavel Windows|*.exe'}else{'Imagens|*.jpg;*.jpeg;*.png;*.bmp'}
            $browse.Add_Click({$choose=New-Object Microsoft.Win32.OpenFileDialog;$choose.Filter=$filter;if($choose.ShowDialog() -eq $true){$box.Text=$choose.FileName}}.GetNewClosure())
            [void]$row.Children.Add($browse)
        }
        if($spec[0] -eq 'arguments'){$box.AcceptsReturn=$true;$box.Height=65}
        [void]$row.Children.Add($box);[void]$stack.Children.Add($row)
    }
    if($Existing){
        $fields.title.Text=$Existing.title;$fields.exe.Text=Resolve-CatalogPath $Existing.libraryRoot $Existing.executable
        $fields.working.Text=Resolve-CatalogPath $Existing.libraryRoot $Existing.workingDirectory
        $fields.cover.Text=$Existing.cover;$fields.screenshot.Text=$Existing.screenshot;$fields.version.Text=$Existing.version
        $fields.download.Text=$Existing.downloadLink;$fields.description.Text=$Existing.description;$fields.arguments.Text=($Existing.arguments -join "`r`n")
    }
    $errorText=New-Object Windows.Controls.TextBlock;$errorText.Foreground='DarkRed';$errorText.TextWrapping='Wrap';[void]$stack.Children.Add($errorText)
    $save=New-Object Windows.Controls.Button;$save.Content='Salvar jogo';$save.Margin='0,18,0,0';$save.Padding='12,8';[void]$stack.Children.Add($save)
    $save.Add_Click({try{
        if([string]::IsNullOrWhiteSpace($fields.title.Text)){throw 'Informe o nome do jogo.'}
        $id=if($Existing){$Existing.id}else{''}
        $game=New-AdditionalGame $fields.title.Text.Trim() $fields.exe.Text.Trim() $id
        if($fields.working.Text.Trim()){
            $wd=[IO.Path]::GetFullPath($fields.working.Text.Trim())
            if($wd -ine $game.libraryRoot){throw 'Nesta versao, a pasta de trabalho deve ser a pasta do executavel.'}
        }
        foreach($key in 'cover','screenshot'){if($fields[$key].Text.Trim() -and -not [IO.File]::Exists($fields[$key].Text.Trim())){throw ('Imagem nao encontrada: '+$key)}}
        $game.cover=$fields.cover.Text.Trim();$game.screenshot=$fields.screenshot.Text.Trim();$game.version=$fields.version.Text.Trim();$game.description=$fields.description.Text
        $game.downloadLink=$fields.download.Text.Trim();$game.arguments=@($fields.arguments.Text -split '\r?\n'|Where-Object {$_ -ne ''})
        if($game.downloadLink -and $game.downloadLink -notmatch '^https://t\.me/'){throw 'Use um link https://t.me/ para download automatico.'}
        Save-AdditionalGame $game $script:AppRoot
        $dialog.Tag=$game.id;$dialog.DialogResult=$true
    }catch{$errorText.Text=$_.Exception.Message}})
    $scroll=New-Object Windows.Controls.ScrollViewer;$scroll.VerticalScrollBarVisibility='Auto';$scroll.Content=$stack;$dialog.Content=$scroll
    if($dialog.ShowDialog() -eq $true){
        $Search.Text='';Load-Catalog
        Enter-Platform 'Todas as plataformas'
        foreach($tile in $Games.Items){if($tile.Tag.id -eq $dialog.Tag){$Games.SelectedItem=$tile;$Games.ScrollIntoView($tile);break}}
        Set-Status 'Jogo salvo no catalogo complementar.'
    }
}
$addButton.Add_Click({Open-AdditionalGameEditor})
$editButton.Add_Click({if($script:Selected -and $script:Selected.PSObject.Properties['libraryRoot']){Open-AdditionalGameEditor $script:Selected}else{Set-Status 'Este botao edita os jogos adicionados pelo nosso launcher.'}})
$Games.Add_SelectionChanged({ $script:Selected = if ($Games.SelectedItem) { $Games.SelectedItem.Tag } else { $null }; if ($null -eq $script:Selected) { return }; $Title.Text=$script:Selected.title; $Meta.Text=('{0}  •  {1}' -f $script:Selected.category,$script:Selected.variant); $Description.Text=if ($script:Selected.description) {$script:Selected.description} else {'Sem descrição cadastrada.'}; $Play.IsEnabled=$true; $Details.IsEnabled=$true })
function Get-DownloadRequestInfo($game) {
    if (-not $game -or -not $game.PSObject.Properties['downloadLink']) { throw 'Este jogo nao possui fonte de download cadastrada.' }
    $url = $null
    if (-not [Uri]::TryCreate($game.downloadLink,[UriKind]::Absolute,[ref]$url) -or $url.Scheme -notin @('https','http')) { throw 'Link de download ausente ou invalido.' }
    $tools=Get-InstallTools
    if(-not(Test-Path -LiteralPath $tools.session)){throw 'Conta nao conectada neste PC. Use Configuracoes > Conectar Telegram e leia o QR pelo celular. Nao precisa instalar Telegram Desktop.'}
    if($game.id -notmatch '^[a-zA-Z0-9._-]+$'){throw 'Identificador de jogo invalido.'}
    return @{url=$url;tools=$tools}
}
# Rotulo do botao principal: Jogar / Baixar / Adicionar a fila / Baixando...
function Update-PlayLabel {
    if(-not $script:Selected){return}
    try{$installed=[IO.File]::Exists((Resolve-CatalogPath (Get-GameRoot $script:Selected) $script:Selected.executable))}catch{return}
    $Play.Content=if($installed){'Jogar'}elseif($script:ActiveInstall){if($script:InstallGame -and $script:InstallGame.id -ceq $script:Selected.id){'Baixando...'}else{'Adicionar a fila'}}else{'Baixar'}
}
function Clear-ActiveInstall {
    $script:ActiveInstall=$null;$cancelButton.Visibility='Collapsed';$OperationProgress.Visibility='Collapsed'
    Update-PlayLabel
}
# Inicia imediatamente o download de UM jogo (nao usa fila).
function Start-GameDownload($game) {
    if($script:ActiveInstall){throw 'Aguarde a operacao atual terminar ou cancele.'}
    $info=Get-DownloadRequestInfo $game;$url=$info.url;$tools=$info.tools
    $jobDir=Join-Path $script:AppRoot ('Cache\Operacoes\'+[Guid]::NewGuid().ToString('N'))
    # Retoma somente uma operacao falha do mesmo jogo/fonte nesta biblioteca.
    $operations=Join-Path $script:AppRoot 'Cache\Operacoes'
    if(Test-Path -LiteralPath $operations){
        foreach($previous in (Get-ChildItem -LiteralPath $operations -Directory|Sort-Object LastWriteTime -Descending)){
            if($previous.Name -cnotmatch '^[a-f0-9]{32}$' -or ($previous.Attributes -band [IO.FileAttributes]::ReparsePoint)){continue}
            try{
                $oldStatus=Read-CentralJson (Join-Path $previous.FullName 'status.json')
                $oldRequest=Read-CentralJson (Join-Path $previous.FullName 'request.json')
                if($oldStatus.state -eq 'error' -and $oldRequest.id -ceq $game.id -and $oldRequest.link -ceq $url.AbsoluteUri -and $oldRequest.appRoot -ieq $script:AppRoot -and $oldRequest.executable -ceq $game.executable){
                    $jobDir=$previous.FullName
                    break
                }
            }catch{}
        }
    }
    New-Item -ItemType Directory -Path $jobDir -Force|Out-Null
    $request=@{id=$game.id;link=$url.AbsoluteUri;executable=$game.executable;appRoot=$script:AppRoot;tdl=$tools.tdl;unrar=$tools.unrar;session=$tools.session}
    if(-not $game.PSObject.Properties['managedRoot']){
        $segments=$game.executable -split '[\\/]'
        if($segments.Count -ge 3 -and $segments[0] -eq 'Jogos'){
            $originalDirectory=Resolve-CatalogPath $script:GamesRoot ($segments[0]+'\'+$segments[1])
            if(Test-Path -LiteralPath $originalDirectory){$request['originalDirectory']=$originalDirectory}
        }
    }
    $requestFile=Join-Path $jobDir 'request.json'
    [IO.File]::WriteAllText($requestFile,($request|ConvertTo-Json),[Text.Encoding]::UTF8)
    foreach($marker in @('cancel','status.json')){ $markerPath=Join-Path $jobDir $marker;if(Test-Path -LiteralPath $markerPath){Remove-Item -LiteralPath $markerPath -Force} }
    $script:InstallGame=$game
    $script:InstallProcess=Start-Process powershell.exe -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File '+(ConvertTo-WindowsArgument (Join-Path $PSScriptRoot 'InstallWorker.ps1'))+' -Request '+(ConvertTo-WindowsArgument $requestFile)) -WindowStyle Hidden -PassThru
    $script:ActiveInstall=$jobDir;$cancelButton.Visibility='Visible'
    $OperationProgress.Visibility='Visible'
    Set-Status 'Preparando download...'
    Update-PlayLabel
}
# Botao Baixar/Atualizar: se ja houver download em andamento, o jogo entra na fila.
function Open-DownloadSource {
    if(-not $script:Selected){return}
    [void](Get-DownloadRequestInfo $script:Selected)
    if($script:ActiveInstall){
        $activeId=if($script:InstallGame){[string]$script:InstallGame.id}else{''}
        switch(Add-DownloadQueueItem $script:DownloadQueue ([string]$script:Selected.id) ([string]$script:Selected.title) $activeId){
            'active' {Set-Status 'Este jogo ja esta sendo baixado.'}
            'queued' {Set-Status ('Este jogo ja esta na fila (posicao '+(Get-DownloadQueuePosition $script:DownloadQueue ([string]$script:Selected.id))+').')}
            'added'  {$script:QueueUsed=$true;Set-Status ('Adicionado a fila: '+$script:Selected.title+' (posicao '+$script:DownloadQueue.Count+'). Veja em Configuracoes > Fila de downloads.')}
        }
        return
    }
    Start-GameDownload $script:Selected
}
# Inicia o proximo item da fila. Retorna $true se um download foi iniciado.
function Start-NextQueuedDownload {
    while(-not $script:ActiveInstall){
        $next=Get-NextDownloadQueueItem $script:DownloadQueue
        if($null -eq $next){return $false}
        $game=$script:Catalog|Where-Object id -eq $next.id|Select-Object -First 1
        if(-not $game){[void]$script:QueueResults.Add('Falhou: '+$next.title+' (nao esta mais no catalogo)');continue}
        try{Start-GameDownload $game;return $true}
        catch{[void]$script:QueueResults.Add('Falhou: '+$next.title+' ('+$_.Exception.Message+')')}
    }
    return $false
}
# Ao terminar a fila (mais de um item), mostra um resumo. Retorna $true se mostrou.
function Show-QueueSummaryIfNeeded {
    $results=@($script:QueueResults);$used=$script:QueueUsed
    $script:QueueResults.Clear();$script:QueueUsed=$false
    if(-not $used -or $results.Count -eq 0){return $false}
    [void][Windows.MessageBox]::Show(($results -join "`n"),'Fila de downloads concluida')
    return $true
}
$script:QueueRemoveHandler={param($sender,$e)
    $id=[string]$sender.Tag;$title=$id
    foreach($item in $script:DownloadQueue){if($item.id -ceq $id){$title=$item.title}}
    if(Remove-DownloadQueueItem $script:DownloadQueue $id){Set-Status ('Removido da fila: '+$title)}
}
$script:QueueClearHandler={param($sender,$e) $script:DownloadQueue.Clear();Set-Status 'Fila de downloads limpa.'}
function Show-DownloadQueue {
    if($script:DownloadQueue.Count -eq 0){Set-Status 'A fila de downloads esta vazia.';return}
    $actions=@()
    foreach($item in @($script:DownloadQueue)){
        $remove=New-Object Windows.Controls.Button;$remove.Tag=[string]$item.id;$remove.Add_Click($script:QueueRemoveHandler)
        $actions+=@{label=('Remover da fila: '+$item.title);source=$remove;enabled=$true}
    }
    $clear=New-Object Windows.Controls.Button;$clear.Add_Click($script:QueueClearHandler)
    $actions+=@{label='Limpar a fila inteira';source=$clear;enabled=$true}
    Show-LauncherActionList ('Fila de downloads ('+$script:DownloadQueue.Count+')') $actions
}
$UpdateButton.Add_Click({ try { Open-DownloadSource } catch { Set-Status $_.Exception.Message $true } })
$Games.Add_SelectionChanged({
    $CoverImage.Source = $null
    if (-not $script:Selected) { return }
    try {
        $ScreenshotNotice.Visibility='Visible'
        $CoverImage.Visibility='Collapsed'
        if ($script:Selected.screenshot -and (Test-Path -LiteralPath $script:Selected.screenshot)) {
            $bitmap = New-Object Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit(); $bitmap.CacheOption = 'OnLoad'; $bitmap.DecodePixelHeight = 450
            $bitmap.UriSource = [Uri]$script:Selected.screenshot; $bitmap.EndInit(); $bitmap.Freeze(); $CoverImage.Source = $bitmap
            $CoverImage.Visibility='Visible';$ScreenshotNotice.Visibility='Collapsed'
        }
        $installed = Test-Path -LiteralPath (Resolve-CatalogPath (Get-GameRoot $script:Selected) $script:Selected.executable) -PathType Leaf
        $versionText = if (-not $installed) { 'Versao instalada: nenhuma' } elseif ([string]::IsNullOrWhiteSpace($script:Selected.version)) { 'Versao instalada: sem registro local' } else { 'Versao instalada: ' + $script:Selected.version }
        if($installed -and $script:Selected.PSObject.Properties['versionVerified'] -and -not $script:Selected.versionVerified){$versionText='Versao instalada: registro antigo nao confirmado'}
        $Meta.Text = $(if ($installed) { 'Instalado' } else { 'Nao instalado' }) + "`n" + $versionText
        if($script:Selected.PSObject.Properties['availableVersion']){
            $Meta.Text += "`nNo acervo (Arquivista): " + $(if($script:Selected.availableVersion){$script:Selected.availableVersion}else{'nao informado'})
            if($script:Selected.versionChecked){$Meta.Text += "`nConferido: " + $script:Selected.versionChecked}
        }
        Update-PlayLabel
        $UpdateButton.IsEnabled = $installed
        $UpdateButton.Visibility = if ($installed) { 'Visible' } else { 'Collapsed' }
        Show-GameMetadata
        Show-GraphicsInfo
    } catch { Set-Status $_.Exception.Message $true }
})
$Play.Add_Click({ try {
    $exe = Resolve-CatalogPath (Get-GameRoot $script:Selected) $script:Selected.executable
    if (-not [IO.File]::Exists($exe)) { Open-DownloadSource; return }
    if ($script:Selected.PSObject.Properties['legacyArguments'] -and $script:Selected.legacyArguments) { throw 'Este jogo usa argumentos antigos e precisa de revisao antes de executar.' }
    if ([IO.Path]::GetExtension($exe) -ine '.exe') { throw 'Esta entrada precisa de um executavel .exe confirmado.' }
    Apply-GraphicsPreference $script:Selected (Get-GameRoot $script:Selected) $script:AppRoot
    $p = Start-CatalogGame $script:Selected (Get-GameRoot $script:Selected)
    Set-Status "Executando '$($script:Selected.title)' (PID $($p.Id))."
} catch { Set-Status $_.Exception.Message $true } })
$Details.Add_Click({Show-GameDetails})
function Show-GameDetails {
    if(-not $script:Selected){return}
    $game=$script:Selected
    $dialog=New-Object Windows.Window;$dialog.Title='Detalhes - '+$game.title;if($window.IsVisible){$dialog.Owner=$window};$dialog.Width=820;$dialog.Height=650;$dialog.MinWidth=560;$dialog.MinHeight=420;$dialog.WindowStartupLocation='CenterOwner';$dialog.Background='#192226';$dialog.Foreground='White';$dialog.FontFamily='Segoe UI'
    $dock=New-Object Windows.Controls.DockPanel;$dock.Margin='24'
    $close=New-Object Windows.Controls.Button;$close.Content='Voltar a biblioteca';$close.Padding='16,10';$close.HorizontalAlignment='Right';$close.Margin='0,12,0,0';$close.Add_Click({$dialog.Close()});[Windows.Controls.DockPanel]::SetDock($close,'Bottom');[void]$dock.Children.Add($close)
    $scroll=New-Object Windows.Controls.ScrollViewer;$scroll.VerticalScrollBarVisibility='Auto'
    $panel=New-Object Windows.Controls.StackPanel
    $heading=New-Object Windows.Controls.TextBlock;$heading.Text=$game.title;$heading.FontSize=27;$heading.FontWeight='SemiBold';$heading.TextWrapping='Wrap';$heading.Margin='0,0,0,16';[void]$panel.Children.Add($heading)
    if($CoverImage.Source){$shot=New-Object Windows.Controls.Image;$shot.Source=$CoverImage.Source;$shot.MaxHeight=250;$shot.MaxWidth=700;$shot.Stretch='Uniform';$shot.StretchDirection='DownOnly';$shot.HorizontalAlignment='Left';[void]$panel.Children.Add($shot)}
    $state=New-Object Windows.Controls.TextBlock;$state.Text=$Meta.Text;$state.Foreground='#A4D997';$state.Margin='0,16,0,12';[void]$panel.Children.Add($state)
    $players=New-Object Windows.Controls.TextBlock;$players.Text=$PlayerInfo.Text;$players.TextWrapping='Wrap';$players.Margin='0,0,0,16';[void]$panel.Children.Add($players)
    $source=New-Object Windows.Controls.TextBlock;$source.Text=$RatingText.Text;$source.Foreground='#9DB5A4';$source.TextWrapping='Wrap';$source.Margin='0,12,0,12';[void]$panel.Children.Add($source)
    $support=Get-GraphicsSupport $game (Get-GameRoot $game)
    $graphics=New-Object Windows.Controls.TextBlock;$graphics.Text=if($support.Supported){'Renderizador atual: '+$support.Current}else{$support.Message};$graphics.TextWrapping='Wrap';$graphics.Margin='0,0,0,16';[void]$panel.Children.Add($graphics)
    $technical=New-Object Windows.Controls.Expander;$technical.Header='Informacoes tecnicas';$technical.IsExpanded=$false
    $paths=New-Object Windows.Controls.TextBlock;$paths.Text=('Executavel: '+$game.executable+"`nPasta de trabalho: "+$game.workingDirectory);$paths.TextWrapping='Wrap';$paths.Margin='0,8,0,0';$technical.Content=$paths;[void]$panel.Children.Add($technical)
    $scroll.Content=$panel;[void]$dock.Children.Add($scroll);$dialog.Content=$dock
    if($Verify){$dialog.Close();return}
    [void]$dialog.ShowDialog()
}
function Show-GraphicsInfo {
    $GraphicsButton.IsEnabled=($null -ne $script:Selected)
    if(-not $script:Selected){$GraphicsInfo.Text='';return}
    $s=Get-GraphicsSupport $script:Selected (Get-GameRoot $script:Selected)
    if($s.Supported){
        $prefs=Read-GraphicsPreferences $script:AppRoot
        $GraphicsInfo.Text='API no jogo: '+$s.Current
        if($prefs.ContainsKey($script:Selected.id)){$GraphicsInfo.Text+="`nPreferencia: "+$prefs[$script:Selected.id]}
    }else{$GraphicsInfo.Text=$s.Message}
}
$GraphicsButton.Add_Click({try{
    if(-not $script:Selected){return}
    $game=$script:Selected;$root=Get-GameRoot $game;$support=Get-GraphicsSupport $game $root
    if(-not $support.Supported){[void][Windows.MessageBox]::Show($support.Message,'Renderizador');return}
    $dialog=New-Object Windows.Window;$dialog.Title='Renderizador - '+$game.title;$dialog.Owner=$window;$dialog.Width=480;$dialog.SizeToContent='Height';$dialog.WindowStartupLocation='CenterOwner';$dialog.ResizeMode='NoResize'
    $panel=New-Object Windows.Controls.StackPanel;$panel.Margin='20'
    $text=New-Object Windows.Controls.TextBlock;$text.TextWrapping='Wrap';$text.Text=$support.Message+"`n`nA escolha sera aplicada no proximo Jogar. O arquivo graphics.json recebe backup; os demais ajustes sao mantidos.";$text.Margin='0,0,0,16';[void]$panel.Children.Add($text)
    $combo=New-Object Windows.Controls.ComboBox;$combo.DisplayMemberPath='Label';$combo.Margin='0,0,0,16'
    $labels=@{Keep='Manter configuracao do jogo';Auto='Automatico (padrao do port)';D3D12='Direct3D 12';Vulkan='Vulkan'}
    $prefs=Read-GraphicsPreferences $script:AppRoot;$selected='Keep';if($prefs.ContainsKey($game.id)){$selected=$prefs[$game.id]}
    foreach($key in $support.Options){$item=[pscustomobject]@{Key=$key;Label=$labels[$key]};[void]$combo.Items.Add($item);if($key -eq $selected){$combo.SelectedItem=$item}}
    [void]$panel.Children.Add($combo)
    $save=New-Object Windows.Controls.Button;$save.Content='Salvar para este jogo';$save.Padding='12,8';$save.Add_Click({$dialog.DialogResult=$true});[void]$panel.Children.Add($save);$dialog.Content=$panel
    if($dialog.ShowDialog() -eq $true){Save-GraphicsPreference $game $root $script:AppRoot $combo.SelectedItem.Key;Show-GraphicsInfo;Set-Status 'Renderizador salvo. Sera aplicado ao jogar.'}
}catch{Set-Status $_.Exception.Message $true}})
function Get-MetadataPath($game) {
    if($game.id -notmatch '^[a-zA-Z0-9._-]+$'){throw 'Identificador invalido.'}
    return Join-Path $script:AppRoot ('Dados\Metadados\'+$game.id+'.json')
}
function Show-GameMetadata {
    $RatingText.Text=''
    $PlayerInfo.Text='Jogadores: nao informado'
    if(-not $script:Selected){return}
    $file=Get-MetadataPath $script:Selected
    if(Test-Path -LiteralPath $file){
        $meta=Read-CentralJson $file
        if($meta.PSObject.Properties['playersLabel']){$PlayerInfo.Text='Jogadores: '+$meta.playersLabel+' (edicao original)'}
        if($meta.PSObject.Properties['developer'] -and $meta.developer){$PlayerInfo.Text+="`nDesenvolvedora: "+$meta.developer}
        if($meta.PSObject.Properties['publisher'] -and $meta.publisher){$PlayerInfo.Text+="`nPublisher: "+$meta.publisher}
    }
    $playerFile=Join-Path $script:AppRoot 'Dados\jogadores.json'
    if(Test-Path -LiteralPath $playerFile){$known=Read-CentralJson $playerFile;$entry=$known.PSObject.Properties[$script:Selected.id];if($entry){$PlayerInfo.Text=$PlayerInfo.Text -replace '^Jogadores:[^\r\n]*',('Jogadores: '+$entry.Value.label+' (edicao original)')}}
}
$Games.Add_SelectionChanged({$detailScroll.ScrollToTop()})
function Start-BaseUpdateCheck {
    if($script:BaseCheck -or -not $script:GamesRoot){return}
    $folder=Join-Path $script:AppRoot 'Cache\AtualizacaoBase';New-Item -ItemType Directory -Force -Path $folder|Out-Null
    $output=Join-Path $folder ([Guid]::NewGuid().ToString('N')+'.json')
    $argsText='-NoProfile -ExecutionPolicy Bypass -File '+(ConvertTo-WindowsArgument (Join-Path $PSScriptRoot 'BaseUpdateWorker.ps1'))+' -Root '+(ConvertTo-WindowsArgument $script:GamesRoot)+' -Output '+(ConvertTo-WindowsArgument $output)
    $process=Start-Process powershell.exe -ArgumentList $argsText -WindowStyle Hidden -PassThru
    $script:BaseCheck=@{output=$output;root=$script:GamesRoot;started=[DateTime]::UtcNow;process=$process}
    $BaseUpdateText.Text='Consultando atualizacao do Central original...';$BaseUpdateText.Foreground='#BDCEBF';$baseCheckButton.IsEnabled=$false
}
$baseCheckButton.Add_Click({Start-BaseUpdateCheck})
$baseTimer=New-Object Windows.Threading.DispatcherTimer;$baseTimer.Interval=[TimeSpan]::FromSeconds(1)
$baseTimer.Add_Tick({
    if(-not $script:BaseCheck){return}
    try{
        $check=$script:BaseCheck
        if(-not(Test-Path -LiteralPath $check.output)){
            if(($check.process.HasExited) -or (([DateTime]::UtcNow-$check.started).TotalSeconds -gt 30)){$script:BaseCheck=$null;$baseCheckButton.IsEnabled=$true;$BaseUpdateText.Text='Verificacao da base indisponivel. Tente novamente mais tarde.';$script:BaseLatestResult=[pscustomobject]@{state='error';version='?';message=$BaseUpdateText.Text};$script:BaseLatestRoot=$check.root}
            return
        }
        $result=Read-CentralJson $check.output;$script:BaseCheck=$null;$baseCheckButton.IsEnabled=$true
        if($check.root -ne $script:GamesRoot){Start-BaseUpdateCheck;return}
        $script:BaseLatestResult=$result;$script:BaseLatestRoot=$check.root
        $BaseUpdateText.Text='Central original v'+$result.version+' — '+$result.message
        $BaseUpdateText.Foreground=if($result.state -eq 'changed'){'#FFE08A'}else{'#BDCEBF'}
        $BaseUpdateText.ToolTip='A consulta compara o pacote da base. Nao instala arquivos nem verifica updates dos jogos.'
    }catch{$script:BaseCheck=$null;$baseCheckButton.IsEnabled=$true;$BaseUpdateText.Text='Nao foi possivel verificar a base agora.';$script:BaseLatestResult=[pscustomobject]@{state='error';version='?';message=$BaseUpdateText.Text};$script:BaseLatestRoot=$script:GamesRoot}
})
if(-not $Verify){$baseTimer.Start()}
$window.Add_Closed({$baseTimer.Stop()})
$sibling = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Central Arquivista - WinPort'
$installTimer=New-Object Windows.Threading.DispatcherTimer
. (Join-Path $PSScriptRoot 'InstallCleanup.ps1')
if(-not $Verify){try{[void](Clear-StaleLauncherCache -AppRoot $script:AppRoot)}catch{}}
$installTimer.Interval=[TimeSpan]::FromSeconds(1)
$installTimer.Add_Tick({
    if(-not $script:ActiveInstall){return}
    try{
        $statusPath=Join-Path $script:ActiveInstall 'status.json'
        if(-not(Test-Path -LiteralPath $statusPath)){return}
        $result=Read-SharedJson $statusPath
        if($null -eq $result){return}
        $bytes=0; $downloadPath=Join-Path $script:ActiveInstall 'downloads'
        if(Test-Path -LiteralPath $downloadPath){$bytes=Get-CatalogFilesSize @(Get-ChildItem -LiteralPath $downloadPath -File)}
        Set-Status ($result.message+$(if($bytes){' | '+[Math]::Round($bytes/1MB,1)+' MB recebidos'}else{''})+$(if($script:DownloadQueue.Count){' | Fila: '+$script:DownloadQueue.Count+' aguardando'}else{''})) ($result.state -eq 'error')
        if($result.state -eq 'error'){
            $failedTitle=if($script:InstallGame){$script:InstallGame.title}else{[string]$result.id}
            $shortReason=[string]$result.message;if($shortReason.Length -gt 160){$shortReason=$shortReason.Substring(0,160)+'...'}
            Clear-ActiveInstall
            [void]$script:QueueResults.Add('Falhou: '+$failedTitle+' ('+$shortReason+')')
            if(Start-NextQueuedDownload){return}
            [void](Show-QueueSummaryIfNeeded)
            return
        }
        if($result.state -ne 'done'){return}
        $completedId=$result.id;$completedJob=$script:ActiveInstall;$registered=$false
        try{
            $mapFile=Join-Path $script:AppRoot 'Dados\instalados.json'
            $map=@{}
            if(Test-Path -LiteralPath $mapFile){
                $recovered=$false
                try{$old=Read-CentralJson $mapFile}
                catch{if(Test-Path -LiteralPath ($mapFile+'.bak')){$old=Read-CentralJson ($mapFile+'.bak');$recovered=$true}else{throw}}
                foreach($prop in $old.PSObject.Properties){$map[$prop.Name]=$prop.Value}
                # Nunca sobrescrever uma copia .bak boa com um arquivo corrompido.
                if($recovered){Copy-Item -LiteralPath $mapFile -Destination ($mapFile+'.corrompido-'+[Guid]::NewGuid().ToString('N')) -Force}
                else{Copy-Item -LiteralPath $mapFile -Destination ($mapFile+'.bak') -Force}
            }
            $map[$result.id]=@{version=$result.version;root=$result.root;executable=$result.executable;author=$result.author;versionSource=$result.versionSource;versionMessageId=$result.versionMessageId}
            [IO.File]::WriteAllText(($mapFile+'.tmp'),($map|ConvertTo-Json -Depth 6),[Text.Encoding]::UTF8)
            Move-Item -LiteralPath ($mapFile+'.tmp') -Destination $mapFile -Force
            $registered=$true
        }catch{Set-Status ('Jogo instalado, mas o registro falhou: '+$_.Exception.Message) $true}
        # Libera a interface sempre: antes, uma falha aqui deixava a operacao "ativa" repetindo o erro a cada segundo.
        Clear-ActiveInstall
        if(-not $registered){
            [void]$script:QueueResults.Add('Falhou: '+$completedId+' (instalado, mas o registro falhou)')
            if(-not(Start-NextQueuedDownload)){[void](Show-QueueSummaryIfNeeded)}
            return
        }
        try{[void](Clear-CompletedInstallCache -AppRoot $script:AppRoot -Job $completedJob)}catch{Set-Status ('Jogo instalado. Nao foi possivel limpar o cache: '+$_.Exception.Message) $true}
        Load-Catalog
        $game=$script:Catalog|Where-Object id -eq $completedId|Select-Object -First 1
        $doneTitle=if($game){$game.title}else{$completedId}
        [void]$script:QueueResults.Add('Instalado: '+$doneTitle)
        # Com itens na fila, o proximo comeca ja e a pergunta "Jogar agora" nao interrompe o lote.
        if(Start-NextQueuedDownload){Set-Status ($doneTitle+' instalado. Proximo da fila iniciado.');return}
        if(Show-QueueSummaryIfNeeded){return}
        $prompt=New-Object Windows.Window
        $prompt.Title='Instalacao concluida';$prompt.Owner=$window;$prompt.SizeToContent='WidthAndHeight';$prompt.WindowStartupLocation='CenterOwner';$prompt.ResizeMode='NoResize'
        $panel=New-Object Windows.Controls.StackPanel;$panel.Margin='24'
        $label=New-Object Windows.Controls.TextBlock;$label.Text='Instalacao concluida. Deseja abrir o jogo agora?';$label.Margin='0,0,0,20';[void]$panel.Children.Add($label)
        $row=New-Object Windows.Controls.StackPanel;$row.Orientation='Horizontal'
        $yes=New-Object Windows.Controls.Button;$yes.Content='Jogar agora';$yes.Padding='12,8';$yes.Margin='0,0,12,0';$yes.Add_Click({$prompt.DialogResult=$true})
        $no=New-Object Windows.Controls.Button;$no.Content='Voltar a biblioteca';$no.Padding='12,8';$no.Add_Click({$prompt.DialogResult=$false})
        [void]$row.Children.Add($yes);[void]$row.Children.Add($no);[void]$panel.Children.Add($row);$prompt.Content=$panel
        if($prompt.ShowDialog() -eq $true){
            if($game.legacyArguments){throw 'Instalado. Os argumentos deste jogo precisam de revisao antes da primeira execucao.'}
            Apply-GraphicsPreference $game (Get-GameRoot $game) $script:AppRoot
            [void](Start-CatalogGame $game (Get-GameRoot $game))
        }
    }catch{Set-Status $_.Exception.Message $true}
})
$installTimer.Start()
$window.Add_Closed({$installTimer.Stop();$script:DownloadQueue.Clear();if($script:ActiveInstall){[IO.File]::WriteAllText((Join-Path $script:ActiveInstall 'cancel'),'cancel')}})
$script:NavigationPlatform='Todas as plataformas'
$sourcePreference=Join-Path $script:AppRoot 'Dados\origem.json'
if(Test-Path -LiteralPath $sourcePreference){try{$savedSource=Read-CentralJson $sourcePreference;if(Test-Path -LiteralPath $savedSource.root){$script:Root=$savedSource.root}}catch{}}
if(-not $script:Root -and -not $VerifyClean -and (Test-Path -LiteralPath (Join-Path $sibling 'Arquivismo\Dados\catalogo.json'))){$script:Root=$sibling}
if($script:Root){Load-Catalog}else{$homeHeading.Text='CONECTE SUA BIBLIOTECA';$BaseUpdateText.Text='Use Escolher biblioteca para conectar a instalacao do Central original. Seus jogos continuam na pasta atual.'}
Initialize-LauncherInput
Show-PlatformHome
. (Join-Path $PSScriptRoot 'FrontendUpdateUI.ps1')
. (Join-Path $PSScriptRoot 'BaseUpdateUI.ps1')
. (Join-Path $PSScriptRoot 'OrganizedUI.ps1')
if($VerifyClean){
    if($script:Catalog.Count -ne 0 -or $script:Root){throw 'Instalacao limpa trouxe biblioteca pessoal.'}
    $window.Measure([Windows.Size]::new(1180,720));$window.Arrange([Windows.Rect]::new(0,0,1180,720));$window.UpdateLayout()
    Write-Output 'PASS: instalacao limpa, biblioteca vazia, interface e controle inicializados.'
    $window.Close()
} elseif ($Verify) {
    if ($Games.Items.Count -eq 0) { throw $Status.Text }
    Write-Output ("WPF OK | Jogos={0} | Selecionado={1} | Raiz={2}" -f $Games.Items.Count,$Title.Text,$script:GamesRoot)
    Write-Output ("Capas={0} | Capa selecionada={1} | Acao={2}" -f @($script:Catalog | Where-Object cover).Count,($null -ne $CoverImage.Source),$Play.Content)
    if(-not $CoverImage.Source){throw 'Captura do primeiro jogo nao carregou.'}
    Write-Output ("Capturas={0} | Proporcao={1} | Ampliacao={2} | Dados={3}" -f @($script:Catalog|Where-Object screenshot).Count,$CoverImage.Stretch,$CoverImage.StretchDirection,$RatingText.Text)
    $window.Measure([Windows.Size]::new(1180,720)); $window.Arrange([Windows.Rect]::new(0,0,1180,720)); $window.UpdateLayout()
    $firstTile = $Games.Items[0]; [void]$firstTile.ApplyTemplate()
    $tileBorder = [Windows.Media.VisualTreeHelper]::GetChild($firstTile,0)
    $tileGrid = $tileBorder.Child
    if ($null -eq $tileGrid.Children[0].Source) { throw 'Miniatura do primeiro cartao nao carregou.' }
    Write-Output 'Miniatura real do cartao: OK'
    Show-GameDetails
    Enter-Platform 'Nintendo 64'
    if(@($Games.Items|Where-Object {(Get-OriginPlatform $_.Tag) -ne 'Nintendo 64'}).Count){throw 'Filtro de plataforma incorreto.'}
    Write-Output ('Filtro Nintendo 64: '+$Games.Items.Count+' jogos; ficha de detalhes criada sem erro.')
    if($script:PlatformButtons.Count -ne $PlatformFilter.Items.Count){throw 'Faltam botoes de plataformas.'}
    Write-Output ('Botoes de plataformas: '+$script:PlatformButtons.Count+'; destaque N64: '+$script:PlatformButtons['Nintendo 64'].BorderBrush)
    $missingLogos=@($script:PlatformButtons.Keys|Where-Object {$script:PlatformButtons[$_].Child.Content.Children[0] -isnot [Windows.Controls.Image]})
    if($missingLogos.Count){throw ('Logos ausentes: '+($missingLogos -join ', '))}
    Write-Output 'Todos os botoes de plataforma possuem logo local.'
    if($PlatformHome.Visibility -ne 'Collapsed' -or $detailBorder.Visibility -ne 'Visible'){throw 'Entrada na plataforma nao alternou as telas.'}
    Show-PlatformHome
    if($Games.IsVisible -or $detailBorder.Visibility -ne 'Collapsed'){throw 'Retorno as plataformas nao ocultou os detalhes.'}
    Write-Output 'Navegacao: plataformas -> jogos e detalhes -> plataformas: OK'
    $pad=[CentralInput.Native]::Poll()
    Write-Output ('Controle detectado: '+$(if($pad.Device){$pad.Device}else{'nenhum'}))
    Enter-Platform 'Todas as plataformas'
    $bodyTile=@($Games.Items|Where-Object {$_.Tag.id -eq 'local-body-harvest-n64'})
    if($bodyTile.Count){
        $Games.SelectedItem=$bodyTile[0]
        $bodySupport=Get-GraphicsSupport $script:Selected (Get-GameRoot $script:Selected)
        $bodyExists=[IO.File]::Exists((Resolve-CatalogPath (Get-GameRoot $script:Selected) $script:Selected.executable))
        $expectedAction=if($bodyExists){'Jogar'}else{'Baixar'}
        if($Title.Text -ne $script:Selected.title -or $Play.Content -ne $expectedAction){throw 'Selecao ou acao do Body Harvest incoerente com o disco.'}
        Write-Output ('Body Harvest: selecionado; acao='+$Play.Content+'; '+$bodySupport.Message)
    }
    $window.Close()
} else { [void]$window.ShowDialog() }
