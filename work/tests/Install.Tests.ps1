$ErrorActionPreference='Stop'
$sandbox=Join-Path ([IO.Path]::GetTempPath()) ('CentralInstallTest-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox|Out-Null
$tool=Join-Path $sandbox 'FixtureTool.exe'
$code=@'
using System;
using System.IO;
public class FixtureTool {
 public static void Main(string[] args) {
  if(Array.IndexOf(args,"export")>=0){if(args[Array.IndexOf(args,"-i")+1]!="122,124")throw new Exception("Consulta sem intervalo restrito");File.WriteAllText(args[Array.IndexOf(args,"-o")+1],"{\"messages\":[{\"id\":999,\"text\":\"Versao\\nOutro jogo - 9.9.9\"},{\"id\":123,\"text\":\"Versao\\nFixture - 1.2.3\"}]}");return;}
  if(Array.IndexOf(args,"dl")>=0){string d=args[Array.IndexOf(args,"-d")+1];Directory.CreateDirectory(d);File.WriteAllText(Path.Combine(d,"fixture.rar"),"fixture");return;}
  if(args[0]=="lb"){Console.WriteLine(File.Exists("unsafe") ? "../escape.exe" : "Game.exe\nsettings.ini");return;}
  if(args[0]=="x"){string d=args[args.Length-1];Directory.CreateDirectory(d);File.WriteAllText(Path.Combine(d,"Game.exe"),"new binary");File.WriteAllText(Path.Combine(d,"settings.ini"),"package settings");return;}
 }
}
'@
Add-Type -TypeDefinition $code -OutputAssembly $tool -OutputType ConsoleApplication
$app=Join-Path $sandbox 'app';New-Item -ItemType Directory -Path $app|Out-Null
$session=Join-Path $sandbox 'session.json';[IO.File]::WriteAllText($session,'fixture')
$worker=Join-Path $PSScriptRoot '..\src\InstallWorker.ps1'
function Run-Fixture($name,[bool]$unsafe=$false,$originalDirectory='',[string]$Id='fixture'){
 $job=Join-Path $sandbox $name;New-Item -ItemType Directory -Path $job|Out-Null
 if($unsafe){[IO.File]::WriteAllText((Join-Path $job 'unsafe'),'fixture')}
 $req=@{id=$Id;link='https://t.me/fixture/123';executable='Game.exe';appRoot=$app;session=$session;tdl=$tool;unrar=$tool}
 if($originalDirectory){$req['id']='seeded';$req['originalDirectory']=$originalDirectory}
 $request=Join-Path $job 'request.json';[IO.File]::WriteAllText($request,($req|ConvertTo-Json),[Text.Encoding]::UTF8)
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $worker -Request $request | Out-Null
 Get-Content -LiteralPath (Join-Path $job 'status.json') -Raw -Encoding UTF8|ConvertFrom-Json
}
$install=Run-Fixture 'install'
foreach($badId in @('..\..\outside','C:\outside','UPPER','game/name','')){
 $blocked=Run-Fixture ('invalid-'+[Guid]::NewGuid().ToString('N')) $false '' $badId
 if($blocked.state -ne 'error' -or $blocked.message -notmatch 'inseguro'){throw 'Identificador inseguro aceito.'}
}
if($install.state -ne 'done' -or $install.version -ne '1.2.3'){throw ($install|ConvertTo-Json)}
if($install.versionSource -ne 'arquivista-message' -or $install.versionMessageId -ne '123'){throw 'Origem exata da versao nao registrada.'}
$settings=Join-Path $install.root 'settings.ini';[IO.File]::WriteAllText($settings,'user settings')
$update=Run-Fixture 'update'
if($update.state -ne 'done' -or [IO.File]::ReadAllText($settings) -ne 'user settings'){throw 'Update alterou configuracao'}
$unsafe=Run-Fixture 'unsafe' $true
if($unsafe.state -ne 'error' -or $unsafe.message -notmatch 'inseguro'){throw 'Pacote inseguro foi aceito'}
$original=Join-Path $sandbox 'original';New-Item -ItemType Directory -Path $original|Out-Null
[IO.File]::WriteAllText((Join-Path $original 'settings.ini'),'original settings')
[IO.File]::WriteAllText((Join-Path $original 'Game.exe'),'original binary')
$seeded=Run-Fixture 'seeded' $false $original
if($seeded.state -ne 'done' -or [IO.File]::ReadAllText((Join-Path $seeded.root 'settings.ini')) -ne 'original settings' -or [IO.File]::ReadAllText((Join-Path $original 'Game.exe')) -ne 'original binary'){throw 'Falha ao preservar instalacao original'}
Write-Output 'PASS: instalacao, versao, update, preservacao de configuracao e bloqueio de traversal.'
Write-Output 'PASS: copia da instalacao existente preserva configuracoes e deixa original intacto.'
Write-Output ('Fixtures: '+$sandbox)
