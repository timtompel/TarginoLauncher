$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\Catalog.ps1')
. (Join-Path $PSScriptRoot '..\src\AdditionalCatalog.ps1')
$sandbox=Join-Path ([IO.Path]::GetTempPath()) ('CentralCatalog-'+[Guid]::NewGuid().ToString('N'))
$games=Join-Path $sandbox 'Jogo com espacos';$app=Join-Path $sandbox 'Launcher'
New-Item -ItemType Directory -Path $games,$app|Out-Null
$exe=Join-Path $games 'Game.exe';[IO.File]::WriteAllText($exe,'fixture')
$game=New-AdditionalGame 'Meu jogo' $exe
Save-AdditionalGame $game $app
$saved=@(Read-AdditionalGames $app)
if($saved.Count -ne 1 -or $saved[0].title -ne 'Meu jogo'){throw 'Cadastro nao persistiu'}
$game.title='Titulo corrigido';$game.arguments=@('--name','valor com espacos')
Save-AdditionalGame $game $app
$saved=@(Read-AdditionalGames $app)
if($saved.Count -ne 1 -or $saved[0].id -ne $game.id -or $saved[0].arguments[1] -ne 'valor com espacos'){throw 'Edicao alterou identidade ou argumentos'}
if(-not(Test-Path -LiteralPath (Join-Path $app 'Dados\jogos-adicionais.json.bak'))){throw 'Backup ausente'}
$duplicate=New-AdditionalGame 'Duplicado' $exe
try{Save-AdditionalGame $duplicate $app;throw 'Duplicado aceito'}catch{if($_.Exception.Message -eq 'Duplicado aceito'){throw}}
if(-not(Test-CatalogGame $game $games).Valid){throw 'Pasta de trabalho raiz recusada'}
try{Resolve-CatalogPath $games '..\fora.exe';throw 'Escape aceito'}catch{if($_.Exception.Message -eq 'Escape aceito'){throw}}
Write-Output 'PASS: adicionar, editar, identidade, argumentos, backup, duplicados e confinamento dos caminhos.'
