Set-StrictMode -Version Latest

function Get-OptionalCatalogText($Record,[string]$Name) {
    $property=$Record.PSObject.Properties[$Name]
    if($null -eq $property -or $null -eq $property.Value){return ''}
    return [string]$property.Value
}

function Convert-BaseCatalogEntry($Record) {
    foreach($required in 'Id','Name','Exe'){
        if([string]::IsNullOrWhiteSpace((Get-OptionalCatalogText $Record $required))){throw ('Registro do catalogo sem '+$required)}
    }
    $exe=(Get-OptionalCatalogText $Record 'Exe') -replace '\\','/'
    $directory=Split-Path $exe -Parent;if(-not $directory){$directory='.'}
    [pscustomobject]@{
        id=(Get-OptionalCatalogText $Record 'Id');title=(Get-OptionalCatalogText $Record 'Name')
        executable=$exe;arguments=@();workingDirectory=$directory;category='Importados'
        platform='Windows';originalSystem='';variant='';version=(Get-OptionalCatalogText $Record 'Version')
        cover='';background='';screenshot='';description=(Get-OptionalCatalogText $Record 'Desc')
        legacyArguments=(Get-OptionalCatalogText $Record 'Args')
    }
}

function Read-CentralJson {
    param([Parameter(Mandatory)][string]$Path)
    if (-not [IO.File]::Exists($Path)) { throw "Arquivo não encontrado: $Path" }
    try { return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json) }
    catch { throw "JSON inválido em '$Path': $($_.Exception.Message)" }
}

function Resolve-CatalogPath {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$RelativePath)
    if ([IO.Path]::IsPathRooted($RelativePath)) { throw "O catálogo deve usar caminhos relativos: $RelativePath" }
    $full = [IO.Path]::GetFullPath([IO.Path]::Combine($Root, $RelativePath))
    $rootFull = ([IO.Path]::GetFullPath($Root)).TrimEnd('\') + '\'
    if ($full -ine $rootFull.TrimEnd('\') -and -not $full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) { throw "Caminho fora da raiz: $RelativePath" }
    return $full
}

function Test-CatalogGame {
    param([Parameter(Mandatory)]$Game, [Parameter(Mandatory)][string]$Root)
    $errors = [Collections.Generic.List[string]]::new()
    foreach ($name in 'id','title','executable','workingDirectory') {
        if ([string]::IsNullOrWhiteSpace([string]$Game.$name)) { [void]$errors.Add("Campo obrigatório ausente: $name") }
    }
    try { $exe = Resolve-CatalogPath $Root ([string]$Game.executable) } catch { [void]$errors.Add($_.Exception.Message); $exe = $null }
    try { [void](Resolve-CatalogPath $Root ([string]$Game.workingDirectory)) } catch { [void]$errors.Add($_.Exception.Message) }
    if ($exe -and -not [IO.File]::Exists($exe)) { [void]$errors.Add("Executável ausente: $($Game.executable)") }
    if ($Game.arguments -isnot [Array]) { [void]$errors.Add('arguments deve ser uma lista') }
    [pscustomobject]@{ Valid = ($errors.Count -eq 0); Errors = @($errors) }
}

function Start-CatalogGame {
    param([Parameter(Mandatory)]$Game, [Parameter(Mandatory)][string]$Root)
    $check = Test-CatalogGame $Game $Root
    if (-not $check.Valid) { throw (($check.Errors) -join '; ') }
    $exe = Resolve-CatalogPath $Root $Game.executable
    $wd = Resolve-CatalogPath $Root $Game.workingDirectory
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $exe
    $psi.WorkingDirectory = $wd
    $psi.UseShellExecute = $true
    if ($Game.arguments.Count -gt 0) {
        # Compatível com .NET Framework/PowerShell 5.1: argumentos são
        # serializados para ProcessStartInfo, sem passar por cmd.exe.
        $quoted = foreach ($arg in $Game.arguments) {
            $text = [string]$arg
            if ($text -notmatch '[\s"]') { $text; continue }
            '"' + ([regex]::Replace($text, '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
        }
        $psi.Arguments = ($quoted -join ' ')
    }
    return [Diagnostics.Process]::Start($psi)
}
