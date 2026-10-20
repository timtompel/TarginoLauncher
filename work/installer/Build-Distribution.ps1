param([string]$Workspace=(Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),[ValidatePattern('^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-preview\.[1-9][0-9]*)?$')][string]$Version)
$ErrorActionPreference='Stop'
if(-not $Version){$Version=([IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\project.json'))|ConvertFrom-Json).version}
if($Version -notmatch '^\d+\.\d+\.\d+(-preview\.[1-9][0-9]*)?$'){throw 'Versao do projeto invalida.'}
if(-not(Test-Path -LiteralPath (Join-Path $Workspace 'work\src\UpdatePublicKey.xml'))){throw 'Inicialize a chave publica com Prepare-StableRelease.ps1 -Initialize antes de compilar.'}
$build=Join-Path $Workspace ('work\dist-build-'+[Guid]::NewGuid().ToString('N'))
$payload=Join-Path $build 'payload';$out=Join-Path $Workspace 'outputs'
New-Item -ItemType Directory -Force -Path $payload,$out,(Join-Path $payload 'src'),(Join-Path $payload 'Recursos\Plataformas')|Out-Null
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path -LiteralPath $csc)){throw '.NET Framework Compiler x64 nao encontrado.'}
$manifest=Join-Path $PSScriptRoot 'app.manifest'
$icon=Join-Path $Workspace 'work\distribution-assets\TarginoLauncher.ico'
Copy-Item -LiteralPath $icon -Destination (Join-Path $payload 'Recursos\TarginoLauncher.ico')
New-Item -ItemType Directory -Force -Path (Join-Path $payload 'Recursos\Controles')|Out-Null
Get-ChildItem -LiteralPath (Join-Path $Workspace 'work\distribution-assets\Controles') -File|Where-Object {$_.Extension -in @('.jpg','.txt')}|Copy-Item -Destination (Join-Path $payload 'Recursos\Controles')
$assemblyInfo=Join-Path $build 'AssemblyInfo.cs'
$assemblySource=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'AssemblyInfo.cs')) -replace 'AssemblyInformationalVersion\("[^"]+"\)',('AssemblyInformationalVersion("'+$Version+'")')
[IO.File]::WriteAllText($assemblyInfo,$assemblySource)
$numericVersion=$Version.Split('-')[0]+'.0'
$assemblySource=$assemblySource -replace 'AssemblyVersion\("[^"]+"\)',('AssemblyVersion("'+$numericVersion+'")') -replace 'AssemblyFileVersion\("[^"]+"\)',('AssemblyFileVersion("'+$numericVersion+'")')
[IO.File]::WriteAllText($assemblyInfo,$assemblySource)
$setupSource=Join-Path $build 'Setup.cs'
$setupText=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Setup.cs')) -replace 'public const string Version="[^"]+";',('public const string Version="'+$Version+'";')
[IO.File]::WriteAllText($setupSource,$setupText)
& $csc /nologo /target:winexe /platform:x64 ('/win32manifest:'+$manifest) ('/win32icon:'+$icon) /reference:System.Windows.Forms.dll ('/out:'+(Join-Path $payload 'TarginoLauncher-Recompilados.exe')) (Join-Path $PSScriptRoot 'LauncherEntry.cs') $assemblyInfo
if($LASTEXITCODE){throw 'Falha ao compilar entrada do launcher.'}
& $csc /nologo /target:winexe /platform:x64 ('/win32manifest:'+$manifest) ('/win32icon:'+$icon) /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ('/reference:'+(Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\Microsoft.VisualBasic.dll')) ('/out:'+(Join-Path $payload 'Desinstalar.exe')) (Join-Path $PSScriptRoot 'Uninstall.cs') $assemblyInfo
if($LASTEXITCODE){throw 'Falha ao compilar desinstalador.'}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $Workspace 'work\src') -File){
    if($file.Extension -in @('.ps1','.cs','.xaml') -or $file.Name -eq 'UpdatePublicKey.xml'){[IO.File]::WriteAllText((Join-Path $payload ('src\'+$file.Name)),[IO.File]::ReadAllText($file.FullName),[Text.UTF8Encoding]::new($true))}
}
$logos=Join-Path $Workspace 'work\distribution-assets\Plataformas'
foreach($file in Get-ChildItem -LiteralPath $logos -File){if($file.Extension -in @('.png','.txt','.md')){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $payload ('Recursos\Plataformas\'+$file.Name))}}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'LEIA-ME.txt') -Destination (Join-Path $payload 'LEIA-ME.txt')
[IO.File]::WriteAllText((Join-Path $payload 'versao.json'),(@{product='TarginoLauncher - Recompilados by Central Arquivista';version=$version;channel=$(if($version.Contains('-')){'preview'}else{'stable'})}|ConvertTo-Json),[Text.UTF8Encoding]::new($true))
$relative=@(Get-ChildItem -LiteralPath $payload -Recurse -File|ForEach-Object {$_.FullName.Substring($payload.Length+1)})
$relative+=@('frontend.manifest','file-hashes.txt')
[IO.File]::WriteAllLines((Join-Path $payload 'frontend.manifest'),(@('TarginoLauncher.Recompilados',('version='+$version))+$relative),[Text.UTF8Encoding]::new($false))
$hashes=@(Get-ChildItem -LiteralPath $payload -Recurse -File|Sort-Object FullName|ForEach-Object {(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash+'  '+$_.FullName.Substring($payload.Length+1)})
[IO.File]::WriteAllLines((Join-Path $payload 'file-hashes.txt'),$hashes,[Text.UTF8Encoding]::new($false))
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=Join-Path $build 'payload.zip';[IO.Compression.ZipFile]::CreateFromDirectory($payload,$zip)
$avatar=Join-Path $Workspace 'work\distribution-assets\avatar.png'
$banner=Join-Path $Workspace 'work\distribution-assets\banner.png'
Copy-Item -LiteralPath $avatar -Destination (Join-Path $build 'avatar.png')
Copy-Item -LiteralPath $banner -Destination (Join-Path $build 'banner.png')
$avatar=Join-Path $build 'avatar.png';$banner=Join-Path $build 'banner.png'
$setup=Join-Path $out ('TarginoLauncher-Recompilados-'+$version+'-Setup.exe')
& $csc /nologo /target:winexe /platform:x64 ('/win32manifest:'+$manifest) ('/win32icon:'+$icon) /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll ('/resource:'+$zip+',payload.zip') ('/resource:'+$avatar+',avatar.png') ('/resource:'+$banner+',banner.png') ('/out:'+$setup) $setupSource $assemblyInfo
if($LASTEXITCODE){throw 'Falha ao compilar instalador.'}
Write-Output ('SETUP='+$setup)
Write-Output ('BUILD='+$build)
