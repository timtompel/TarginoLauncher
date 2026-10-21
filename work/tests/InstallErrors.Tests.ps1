$ErrorActionPreference='Stop'
$tokens=$null;$errors=$null
$worker=Join-Path $PSScriptRoot '..\src\InstallWorker.ps1'
$ast=[Management.Automation.Language.Parser]::ParseFile($worker,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Sintaxe invalida no worker'}
$function=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Run-Tool'},$true)
Invoke-Expression $function.Extent.Text
$jobDir=Join-Path $PSScriptRoot ('errors-fixture-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $jobDir|Out-Null
$exe=Join-Path $jobDir 'unrar.exe'
Add-Type -TypeDefinition 'public class FakeUnrar { public static int Main(string[] args) { System.Console.Error.WriteLine("Cannot create file: path too long. token=secret_fixture"); return 9; }}' -OutputAssembly $exe -OutputType ConsoleApplication
$message='';try{Run-Tool $exe @()}catch{$message=$_.Exception.Message}
if($message -notmatch 'UnRAR 9' -or $message -notmatch 'Nao e necessario reconectar Telegram' -or $message -notmatch 'Cannot create file'){throw 'Diagnostico incorreto'}
if($message -match 'secret_fixture'){throw 'Segredo exposto'}
'PASS: erro 9 do descompactador preserva causa e nao acusa autenticacao; detalhes sensiveis ocultados.'
