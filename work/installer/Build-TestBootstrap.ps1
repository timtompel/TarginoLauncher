param([string]$Version='0.1.0-preview.9')
$ErrorActionPreference='Stop'
if($Version -notmatch '^\d+\.\d+\.\d+-preview\.\d+$'){throw 'Somente previa de teste.'}
$workspace=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$package=Get-Item -LiteralPath (Join-Path $workspace ('outputs\TarginoLauncher-Recompilados-'+$Version+'-Setup.exe'))
$hash=(Get-FileHash -LiteralPath $package.FullName -Algorithm SHA256).Hash
$url='https://github.com/timtompel/TarginoLauncher/releases/download/v'+$Version+'/'+$package.Name
$build=Join-Path $workspace ('work\dist-build-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $build|Out-Null
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Bootstrap.cs')).Replace('PACKAGE_URL',$url).Replace('PACKAGE_HASH',$hash).Replace('PACKAGE_SIZE',([string]$package.Length))
$file=Join-Path $build 'Bootstrap.cs';[IO.File]::WriteAllText($file,$source)
$output=Join-Path $workspace ('outputs\TarginoLauncher-Baixador-Teste-'+$Version+'.exe')
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ('/win32manifest:'+(Join-Path $PSScriptRoot 'app.manifest')) ('/win32icon:'+(Join-Path $workspace 'work\distribution-assets\TarginoLauncher.ico')) ('/out:'+$output) $file
if($LASTEXITCODE){throw 'Falha ao compilar baixador.'}
$valid=Start-Process -FilePath $output -ArgumentList ('--verify-package "'+$package.FullName+'"') -WindowStyle Hidden -Wait -PassThru
if($valid.ExitCode){throw 'Baixador recusou o pacote correto.'}
$invalid=Join-Path $build 'invalid.exe';[IO.File]::WriteAllText($invalid,'pacote adulterado')
$rejected=Start-Process -FilePath $output -ArgumentList ('--verify-package "'+$invalid+'"') -WindowStyle Hidden -Wait -PassThru
if($rejected.ExitCode -ne 1){throw 'Baixador aceitou pacote adulterado.'}
Write-Output ('PASS: baixador valida pacote e rejeita adulteracao. OUTPUT='+$output)
