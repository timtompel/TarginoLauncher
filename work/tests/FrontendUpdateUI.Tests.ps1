$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\CentralArquivista.ps1') -VerifyClean
$script:FrontendJob=Join-Path $PSScriptRoot ('update-ui-fixture-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $script:FrontendJob|Out-Null
$script:FrontendProcess=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList '-NoProfile -Command exit' -WindowStyle Hidden -PassThru -Wait
[IO.File]::WriteAllText((Join-Path $script:FrontendJob 'status.json'),'{"state":"none","message":"Nenhuma versao estavel publicada."}')
$FrontendText.Text='Consultando atualizacao do launcher...'
$FrontendProgress.Visibility='Visible'
$statusPath=Join-Path $script:FrontendJob 'status.json'
$blocked=[IO.File]::Open($statusPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try{
    Update-FrontendProgressState
    if(-not $script:FrontendProcess -or $FrontendProgress.Visibility -ne 'Visible'){throw 'Bloqueio temporario cancelou a operacao.'}
    if($FrontendText.Text -ne 'Consultando atualizacao do launcher...'){throw 'Bloqueio temporario exibiu erro.'}
}finally{$blocked.Dispose()}
$preservedStatus=$Status
Update-FrontendProgressState
if(-not [object]::ReferenceEquals($preservedStatus,$Status)){throw 'Leitura sobrescreveu controle Status.'}
$frontendTimer.Start();$cleanTimer.Start()
$frame=New-Object Windows.Threading.DispatcherFrame
$stop=New-Object Windows.Threading.DispatcherTimer;$stop.Interval=[TimeSpan]::FromSeconds(2)
$stop.Add_Tick({$frame.Continue=$false}.GetNewClosure());$stop.Start()
[Windows.Threading.Dispatcher]::PushFrame($frame);$stop.Stop()
if($FrontendText.Text -ne 'Nenhuma versao estavel publicada.'){throw ('Resultado nao exibido: '+$FrontendText.Text)}
if($FrontendProgress.Visibility -ne 'Collapsed'){throw 'Progresso nao foi encerrado.'}
if($script:FrontendProcess){throw 'Processo finalizado permaneceu ativo no estado da UI.'}
$frontendTimer.Stop();$cleanTimer.Stop();$clockTimer.Stop();$officialTimer.Stop()
$script:RequestedMode='';$script:ConfirmedOffer=''
function Start-FrontendOperation([string]$Mode){$script:RequestedMode=$Mode;$script:FrontendPending=$false}
function Confirm-LatestFrontendUpdate {$script:ConfirmedOffer=[string]$FrontendButton.Content}
$script:FrontendPending=$true;$FrontendButton.Content='Instalar 0.1.2'
Request-LatestFrontendUpdate
if($script:RequestedMode -ne 'Check' -or $script:ConfirmedOffer){throw 'Oferta antiga foi confirmada sem nova consulta.'}
if(-not $script:FrontendConfirmAfterCheck){throw 'Intencao de atualizar perdida na consulta.'}
$script:FrontendProcess=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList '-NoProfile -Command exit' -WindowStyle Hidden -PassThru -Wait
[IO.File]::WriteAllText($statusPath,'{"state":"available","message":"Estavel 0.1.4 disponivel","version":"0.1.4","notes":"Nova versao"}')
Update-FrontendProgressState
if($script:ConfirmedOffer -ne 'Instalar 0.1.4'){throw 'Confirmacao nao usa a oferta mais recente.'}
if($script:FrontendConfirmAfterCheck){throw 'Confirmacao automatica permaneceu armada.'}
$script:ConfirmedOffer='';Request-LatestFrontendUpdate
$script:FrontendProcess=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList '-NoProfile -Command exit' -WindowStyle Hidden -PassThru -Wait
[IO.File]::WriteAllText($statusPath,'{"state":"none","message":"Nenhuma versao estavel publicada."}')
Update-FrontendProgressState
if($script:ConfirmedOffer -or $script:FrontendPending -or $script:FrontendConfirmAfterCheck){throw 'Oferta retirada ainda pode ser instalada.'}
Write-Output 'PASS: oferta 0.1.2 em memoria reconsulta e confirma 0.1.4; oferta retirada nao instala.'
Write-Output 'PASS: bloqueio temporario nao cancela operacao; leitura recupera, encerra progresso e preserva controle Status.'
