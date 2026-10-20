param([string]$Version)
$ErrorActionPreference='Stop'
if(-not $Version){$Version=([IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\project.json'))|ConvertFrom-Json).version}
$workspace=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$out=Join-Path $workspace 'outputs'
$kit=Join-Path $workspace ('work\source-kit-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path (Join-Path $kit 'work')|Out-Null
foreach($folder in 'src','installer','distribution-assets'){Copy-Item -LiteralPath (Join-Path $workspace ('work\'+$folder)) -Destination (Join-Path $kit 'work') -Recurse}
foreach($name in 'project.json','README.md','catalog.schema.json','Build-AvatarIcon.cjs','Build-PlatformLogos.cjs'){Copy-Item -LiteralPath (Join-Path $workspace ('work\'+$name)) -Destination (Join-Path $kit 'work')}
New-Item -ItemType Directory -Path (Join-Path $kit 'work\tests')|Out-Null
Get-ChildItem -LiteralPath (Join-Path $workspace 'work\tests') -File -Filter '*.ps1'|Copy-Item -Destination (Join-Path $kit 'work\tests')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LEIA-ME.txt') -Destination (Join-Path $out 'LEIA-ME-DISTRIBUICAO.txt') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LEIA-ME.txt') -Destination (Join-Path $kit 'LEIA-ME.txt')
Add-Type -AssemblyName System.IO.Compression.FileSystem,System.Windows.Forms,System.Drawing
$zip=Join-Path $out ('TarginoLauncher-Recompilados-'+$Version+'-Fontes.zip')
$tempZip=Join-Path $workspace ('work\fontes-'+[Guid]::NewGuid().ToString('N')+'.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($kit,$tempZip)
Move-Item -LiteralPath $tempZip -Destination $zip -Force
$setup=Join-Path $out ('TarginoLauncher-Recompilados-'+$Version+'-Setup.exe')
[void][Reflection.Assembly]::LoadFile($setup)
$form=New-Object Setup
$bitmap=New-Object Drawing.Bitmap $form.ClientSize.Width,$form.ClientSize.Height
$g=[Drawing.Graphics]::FromImage($bitmap);$g.Clear($form.BackColor)
foreach($control in $form.Controls){
    $piece=New-Object Drawing.Bitmap $control.Width,$control.Height
    $control.DrawToBitmap($piece,(New-Object Drawing.Rectangle 0,0,$control.Width,$control.Height))
    $g.DrawImageUnscaled($piece,$control.Left,$control.Top);$piece.Dispose()
    # DrawToBitmap de um TextBox nativo sem janela visivel nao pinta seu conteudo.
    if($control -is [Windows.Forms.TextBox]){
        $g.FillRectangle([Drawing.Brushes]::White,$control.Left,$control.Top,$control.Width,$control.Height)
        $g.DrawString($control.Text,$control.Font,[Drawing.Brushes]::Black,[Drawing.PointF]::new($control.Left+3,$control.Top+3))
    }
}
$g.Dispose();$bitmap.Save((Join-Path $out 'Instalador-preview.png'),[Drawing.Imaging.ImageFormat]::Png);$bitmap.Dispose();$form.Dispose()
$releaseFiles=@(('TarginoLauncher-Recompilados-'+$Version+'-Setup.exe'),('TarginoLauncher-Recompilados-'+$Version+'-Fontes.zip'),'LEIA-ME-DISTRIBUICAO.txt','Instalador-preview.png')
$hashes=foreach($name in $releaseFiles){
    $hash=Get-FileHash -LiteralPath (Join-Path $out $name) -Algorithm SHA256
    $hash.Hash+'  '+$name
}
[IO.File]::WriteAllLines((Join-Path $out 'SHA256SUMS.txt'),$hashes,[Text.UTF8Encoding]::new($false))
Get-ChildItem -LiteralPath $out -File|Select-Object Name,Length
