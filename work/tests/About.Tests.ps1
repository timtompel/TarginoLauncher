$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\CentralArquivista.ps1') -VerifyClean
$originalRoot=$script:AppRoot
$script:AppRoot=Join-Path $PSScriptRoot ('about-fixture-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $script:AppRoot|Out-Null
try{
    New-Item -ItemType Directory -Path (Join-Path $script:AppRoot 'Recursos')|Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\distribution-assets\TarginoLauncher.ico') -Destination (Join-Path $script:AppRoot 'Recursos\TarginoLauncher.ico')
    [IO.File]::WriteAllText((Join-Path $script:AppRoot 'versao.json'),'{"version":"0.1.1","channel":"stable"}')
    $about=Show-LauncherAbout
    $panel=$about.Content.Content
    $avatar=$panel.Children[0].Children[0]
    if($avatar -isnot [Windows.Controls.Image] -or $avatar.Source.PixelWidth -lt 256){throw 'Avatar usa quadro de baixa resolucao.'}
    $text=$panel.Children[1].Text
    if($text -notmatch '0\.1\.1' -or $text -notmatch 'stable' -or $text -notmatch 'Creditos da base: projeto Central Arquivista'){throw 'Versao ou creditos incorretos.'}
    $links=@($panel.Children|Where-Object {$_ -is [Windows.Controls.Button] -and $_.Tag})
    if($links.Count -ne 2){throw 'Links do projeto ausentes.'}
    if(-not $AboutButton -or $AboutButton.Content -ne 'Sobre'){throw 'Acao Sobre ausente.'}
    $about.Measure([Windows.Size]::new(540,650));$about.Arrange([Windows.Rect]::new(0,0,540,650));$about.UpdateLayout()
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap 540,650,96,96,([Windows.Media.PixelFormats]::Pbgra32)
    $about.Content.Measure([Windows.Size]::new(520,610));$about.Content.Arrange([Windows.Rect]::new(0,0,520,610));$about.Content.UpdateLayout()
    $background=New-Object Windows.Media.DrawingVisual;$drawing=$background.RenderOpen();$drawing.DrawRectangle($about.Background,$null,[Windows.Rect]::new(0,0,540,650));$drawing.Close();$bitmap.Render($background)
    $bitmap.Render($about.Content)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $output=Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'outputs\Sobre-avatar-HD.png'
    $stream=[IO.File]::Create($output);try{$encoder.Save($stream)}finally{$stream.Dispose()}
    $about.Close()
    Write-Output 'PASS: Sobre mostra versao instalada, canal, creditos e links; layout criado sem erro.'
}finally{$script:AppRoot=$originalRoot}
