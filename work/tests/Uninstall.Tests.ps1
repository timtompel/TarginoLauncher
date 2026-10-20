$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$source=Join-Path $PSScriptRoot '..\installer\Uninstall.cs'
$vb=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\Microsoft.VisualBasic.dll'
Add-Type -Path $source -ReferencedAssemblies @('System.Windows.Forms','System.Drawing',$vb)
$type=([AppDomain]::CurrentDomain.GetAssemblies()|ForEach-Object {$_.GetType('Uninstall',$false)}|Where-Object {$_}|Select-Object -First 1)
$method=$type.GetMethod('GetLibraryForRemoval',[Reflection.BindingFlags]'Static,NonPublic')
$root=Join-Path $PSScriptRoot ('uninstall-fixture-'+[Guid]::NewGuid().ToString('N'))
$library=Join-Path $root 'Biblioteca';New-Item -ItemType Directory -Path $library -Force|Out-Null
[IO.File]::WriteAllText((Join-Path $library 'save.sav'),'save simulado')
$invokeArgs=New-Object object[] 1;$invokeArgs[0]=[string]$root
if($method.Invoke($null,$invokeArgs) -ine $library){throw 'Destino inesperado.'}
$outside=Join-Path $root 'externo';New-Item -ItemType Directory -Path $outside|Out-Null
New-Item -ItemType Junction -Path (Join-Path $library 'atalho') -Target $outside|Out-Null
$blocked=$false;try{$method.Invoke($null,$invokeArgs)|Out-Null}catch{$blocked=$true}
if(-not $blocked){throw 'Aceitou link dentro da biblioteca.'}
if([IO.File]::ReadAllText((Join-Path $library 'save.sav')) -ne 'save simulado'){throw 'Teste alterou save.'}
$empty=Join-Path $root 'src\subpasta';New-Item -ItemType Directory -Path $empty -Force|Out-Null
$keep=Join-Path $root 'Recursos\arquivo-pessoal.txt';New-Item -ItemType Directory -Path (Split-Path $keep -Parent) -Force|Out-Null;[IO.File]::WriteAllText($keep,'preservar')
$clean=$type.GetMethod('CleanEmptyProgramFolders',[Reflection.BindingFlags]'Static,NonPublic');$clean.Invoke($null,$invokeArgs)
if(Test-Path -LiteralPath (Join-Path $root 'src')){throw 'Pastas vazias nao removidas.'}
if(-not(Test-Path -LiteralPath $keep) -or -not(Test-Path -LiteralPath $library)){throw 'Limpeza de pastas vazias removeu dados.'}
Write-Output 'PASS: remocao restrita a Biblioteca, links bloqueados; teste nao desinstalou nem removeu jogos.'
