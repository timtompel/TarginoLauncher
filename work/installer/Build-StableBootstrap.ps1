param([string]$Workspace=(Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),[string]$Version,[switch]$TestMode,[string]$TestPublicKeyPath,[string]$OutputDirectory)
$ErrorActionPreference='Stop'
if(-not $Version){$Version=([IO.File]::ReadAllText((Join-Path $Workspace 'work\project.json'))|ConvertFrom-Json).version}
if($Version -notmatch '^\d+\.\d+\.\d+$'){throw 'Bootstrap estavel exige versao x.y.z.'}
$publicKey=Join-Path $Workspace 'work\src\UpdatePublicKey.xml'
if($TestMode){if(-not $TestPublicKeyPath -or -not $OutputDirectory){throw 'Teste exige chave e destino isolados.'};$publicKey=$TestPublicKeyPath}
elseif($TestPublicKeyPath){throw 'Chave alternativa exige TestMode.'}
if(-not $OutputDirectory){$OutputDirectory=Join-Path $Workspace 'outputs'}
New-Item -ItemType Directory -Force -Path $OutputDirectory|Out-Null
$build=Join-Path $Workspace ('work\bootstrap-build-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $build|Out-Null
$key=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($publicKey)))
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'StableBootstrap.cs')).Replace('PUBLIC_KEY_BASE64',$key)
$code=Join-Path $build 'StableBootstrap.cs';[IO.File]::WriteAllText($code,$source)
$assembly=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'AssemblyInfo.cs')) -replace 'AssemblyInformationalVersion\("[^"]+"\)',('AssemblyInformationalVersion("'+$Version+'")') -replace 'AssemblyVersion\("[^"]+"\)',('AssemblyVersion("'+$Version+'.0")') -replace 'AssemblyFileVersion\("[^"]+"\)',('AssemblyFileVersion("'+$Version+'.0")')
$info=Join-Path $build 'AssemblyInfo.cs';[IO.File]::WriteAllText($info,$assembly)
$icon=Join-Path $Workspace 'work\distribution-assets\TarginoLauncher.ico'
$output=Join-Path $OutputDirectory $(if($TestMode){'Bootstrap-Fixture-NAO-PUBLICAR.exe'}else{'TarginoLauncher-Bootstrap.exe'})
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Web.Extensions.dll ('/win32manifest:'+(Join-Path $PSScriptRoot 'app.manifest')) ('/win32icon:'+$icon) ('/resource:'+$icon+',brand.ico') ('/out:'+$output) $code $info
if($LASTEXITCODE){throw 'Falha ao compilar bootstrap.'}
Write-Output ('BOOTSTRAP='+$output)
