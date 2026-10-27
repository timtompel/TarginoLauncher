$ErrorActionPreference='Stop'
$tokens=$null;$errors=$null
$worker=Join-Path $PSScriptRoot '..\src\InstallWorker.ps1'
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
. (Join-Path $PSScriptRoot '..\src\GameVersions.ps1')
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
# --- Relogio fora de hora (msg_id too high): mensagem clara e nova tentativa com NTP ---
$function2=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-Tdl'},$true)
if(-not $function2){throw 'Invoke-Tdl ausente no worker.'}
Invoke-Expression $function2.Extent.Text
function Report($state,$message){}
$clockSource='public class FakeTdl { public static int Main(string[] args) { if (System.Array.IndexOf(args, "--ntp") >= 0) { System.Console.WriteLine("ok com ntp"); return 0; } System.Console.Error.WriteLine("Error: group: - initConnection: invoke: rpcDoRequest: msg_id too high"); return 1; }}'
$tdlOk=Join-Path $jobDir 'ok\tdl.exe';New-Item -ItemType Directory -Path (Split-Path $tdlOk -Parent)|Out-Null
Add-Type -TypeDefinition $clockSource -OutputAssembly $tdlOk -OutputType ConsoleApplication
$direct='';try{Run-Tool $tdlOk @('dl')}catch{$direct=$_.Exception.Message}
if($direct -notmatch '^RELOGIO:'){throw 'Run-Tool nao identificou erro de relogio do Telegram.'}
$result=Invoke-Tdl $tdlOk @('dl')
if(([string]$result) -notmatch 'ok com ntp'){throw 'Invoke-Tdl nao tentou novamente com --ntp.'}
$alwaysSource='public class FakeTdlFail { public static int Main(string[] args) { System.Console.Error.WriteLine("msg_id too high"); return 1; }}'
$tdlFail=Join-Path $jobDir 'fail\tdl.exe';New-Item -ItemType Directory -Path (Split-Path $tdlFail -Parent)|Out-Null
Add-Type -TypeDefinition $alwaysSource -OutputAssembly $tdlFail -OutputType ConsoleApplication
$friendly='';try{[void](Invoke-Tdl $tdlFail @('dl'))}catch{$friendly=$_.Exception.Message}
if($friendly -notmatch 'relogio do Windows esta fora de hora' -or $friendly -notmatch 'Sincronizar agora'){throw 'Mensagem de relogio fora de hora ausente ou pouco clara.'}
$function3=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Resolve-InstallVersionInfo'},$true)
if(-not $function3){throw 'Resolve-InstallVersionInfo ausente no worker.'}
Invoke-Expression $function3.Extent.Text
$fallback=Resolve-InstallVersionInfo ([pscustomobject]@{messages=@([pscustomobject]@{id=705;text='Sem versao cadastrada'})}) 'https://t.me/Canal/686/705' '705'
if($fallback.version -ne 'nao informada' -or $fallback.source -notmatch 'sem-versao'){throw 'Post sem versao deveria permitir instalacao com aviso.'}
'PASS: erro 9 do descompactador preserva causa e nao acusa autenticacao; detalhes sensiveis ocultados; erro de relogio do Telegram tenta NTP e orienta o usuario.'
