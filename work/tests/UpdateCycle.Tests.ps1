param([Parameter(Mandatory)][string]$SetupPath)
$ErrorActionPreference='Stop'
$fixture=Join-Path $PSScriptRoot ('cycle-fixture-'+[Guid]::NewGuid().ToString('N'));$root=Join-Path $fixture 'Launcher limpo'
function Install-Test {param([string]$Arguments) $p=Start-Process -FilePath $SetupPath -ArgumentList $Arguments -WindowStyle Hidden -PassThru -Wait;if($p.ExitCode){throw ('Ciclo retornou '+$p.ExitCode)}}
Install-Test ('--test-install "'+$root+'"')
foreach($name in 'Dados','Cache','Biblioteca'){New-Item -ItemType Directory -Path (Join-Path $root $name) -Force|Out-Null;[IO.File]::WriteAllText((Join-Path $root ($name+'\preservar.fixture')),'conteudo mantido')}
$parentExe=Join-Path $fixture 'PaiSimulado.exe'
Add-Type -TypeDefinition 'using System;using System.IO;using System.Threading;class PaiSimulado{static void Main(string[] args){using(var f=new FileStream(args[0],FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None)){Thread.Sleep(1600);}}}' -OutputAssembly $parentExe -OutputType ConsoleApplication
$parent=Start-Process -FilePath $parentExe -ArgumentList ('"'+(Join-Path $root 'Dados\launcher.lock')+'"') -WindowStyle Hidden -PassThru
Install-Test ('--test-apply-update "'+$root+'" '+$parent.Id)
foreach($name in 'Dados','Cache','Biblioteca'){if([IO.File]::ReadAllText((Join-Path $root ($name+'\preservar.fixture'))) -ne 'conteudo mantido'){throw 'Dados nao preservados no ciclo.'}}
if(-not $parent.HasExited){throw 'Pai nao encerrou.'}
Write-Output 'PASS: ciclo espera processo/lock encerrar, instala pelo motor real e reabre WPF VerifyClean; nao modifica registro/atalhos do usuario.'
