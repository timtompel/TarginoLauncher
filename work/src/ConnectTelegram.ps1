param([Parameter(Mandatory)][string]$Tool,[Parameter(Mandatory)][string]$Session)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path (Split-Path $Session -Parent)|Out-Null
# Diferenca entre o relogio do Windows e a hora da internet (NTP). $null se nao foi possivel medir.
function Get-ClockOffsetSeconds {
    $udp=$null
    try{
        $udp=New-Object Net.Sockets.UdpClient;$udp.Client.ReceiveTimeout=3000
        $udp.Connect('time.windows.com',123)
        $request=New-Object byte[] 48;$request[0]=0x1B
        [void]$udp.Send($request,48)
        $endpoint=New-Object Net.IPEndPoint([Net.IPAddress]::Any,0)
        $response=$udp.Receive([ref]$endpoint)
        $seconds=[BitConverter]::ToUInt32([byte[]]@($response[43],$response[42],$response[41],$response[40]),0)
        $server=(New-Object DateTime(1900,1,1,0,0,0,[DateTimeKind]::Utc)).AddSeconds($seconds)
        return ([DateTime]::UtcNow-$server).TotalSeconds
    }catch{return $null}finally{if($udp){$udp.Close()}}
}
Write-Host 'Conecte a conta para baixar os jogos. Escaneie o QR pelo Telegram do celular.'
$offset=Get-ClockOffsetSeconds
if($null -ne $offset -and [Math]::Abs($offset) -gt 20){
    $direction=if($offset -gt 0){'adiantado'}else{'atrasado'}
    Write-Host ('ATENCAO: o relogio do Windows esta ' + $direction + ' cerca de ' + [int][Math]::Abs($offset) + ' segundos.') -ForegroundColor Yellow
    Write-Host 'O Telegram recusa conexoes assim e o QR pode nao aparecer. Corrija em Configuracoes do Windows > Hora e idioma > Sincronizar agora (fuso de Brasilia) e abra esta tela de novo.' -ForegroundColor Yellow
}else{
    Write-Host 'Se o QR nao aparecer em ate 1 minuto, sincronize a hora do Windows (Configuracoes > Hora e idioma > Sincronizar agora) e tente de novo.'
}
& $Tool --storage ('type=file,path='+$Session) login --type qr
if($LASTEXITCODE -ne 0){Write-Host 'Nao foi possivel conectar. Tente novamente.';Read-Host 'Enter para fechar'}
