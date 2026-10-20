. (Join-Path $PSScriptRoot 'FrontendUpdate.ps1')
$script:FrontendJob=$null;$script:FrontendProcess=$null;$script:FrontendMode='';$script:FrontendPending=$false
$script:FrontendReadBlockedAt=$null
$script:FrontendConfirmAfterCheck=$false
$frontendBar=New-Object Windows.Controls.StackPanel;$frontendBar.Margin='18,0,18,6'
[Windows.Controls.DockPanel]::SetDock($frontendBar,'Top');$window.Content.Children.Insert(2,$frontendBar)
$frontendRow=New-Object Windows.Controls.DockPanel;[void]$frontendBar.Children.Add($frontendRow)
$script:FrontendButton=New-Object Windows.Controls.Button;$FrontendButton.Content='Atualizar launcher';$FrontendButton.FontSize=12;$FrontendButton.Padding='10,5';$FrontendButton.Margin='12,0,0,0'
[Windows.Controls.DockPanel]::SetDock($FrontendButton,'Right');[void]$frontendRow.Children.Add($FrontendButton)
$script:FrontendText=New-Object Windows.Controls.TextBlock;$FrontendText.Text='TarginoLauncher: atualizacoes estaveis';$FrontendText.Foreground='#BDCEBF';$FrontendText.VerticalAlignment='Center';$FrontendText.TextWrapping='Wrap';[void]$frontendRow.Children.Add($FrontendText)
$script:FrontendProgress=New-Object Windows.Controls.ProgressBar;$FrontendProgress.Height=8;$FrontendProgress.Margin='0,5,0,0';$FrontendProgress.Visibility='Collapsed';[void]$frontendBar.Children.Add($FrontendProgress)
function Start-FrontendOperation([string]$Mode){
    if($script:FrontendProcess -and -not $script:FrontendProcess.HasExited){return}
    if($Mode -eq 'Check'){
        $script:FrontendPending=$false
        $script:FrontendJob=Join-Path $script:AppRoot ('Cache\AtualizacaoLauncher\'+[Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $script:FrontendJob|Out-Null
    }
    $operationStatusPath=Join-Path $script:FrontendJob 'status.json'
    if(Test-Path -LiteralPath $operationStatusPath){Move-Item -LiteralPath $operationStatusPath -Destination (Join-Path $script:FrontendJob ('status-'+[Guid]::NewGuid().ToString('N')+'.json'))}
    $script:FrontendReadBlockedAt=$null
    $script:FrontendMode=$Mode
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=Join-Path $PSHOME 'powershell.exe'
    $info.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'FrontendUpdateWorker.ps1')+'" -Job "'+$script:FrontendJob+'" -Mode '+$Mode+' -Root "'+$script:AppRoot+'"'
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $script:FrontendProcess=[Diagnostics.Process]::Start($info)
    $FrontendButton.IsEnabled=$false;$FrontendText.Text='Consultando atualizacao do launcher...';$FrontendProgress.IsIndeterminate=$true;$FrontendProgress.Visibility='Visible'
}
function Confirm-LatestFrontendUpdate {
    if($script:ActiveInstall){throw 'Aguarde a instalacao do jogo terminar antes de atualizar o launcher.'}
    $m=Read-FrontendSignedManifest (Join-Path $script:FrontendJob 'update.json') (Join-Path $PSScriptRoot 'UpdatePublicKey.xml')
    $answer=[Windows.MessageBox]::Show($window,('Atualizar o TarginoLauncher para '+$m.version+"?`n`n"+$m.notes+"`n`nO launcher sera fechado. Jogos, saves e o Central original nao serao alterados."),'Atualizacao do launcher','YesNo','Question')
    if($answer -eq 'Yes'){Start-FrontendOperation 'Download'}
}
function Request-LatestFrontendUpdate {
    try{
        if($script:FrontendProcess -and -not $script:FrontendProcess.HasExited){return}
        if($script:ActiveInstall){throw 'Aguarde a instalacao do jogo terminar antes de atualizar o launcher.'}
        $script:FrontendConfirmAfterCheck=[bool]$script:FrontendPending
        Start-FrontendOperation 'Check'
    }catch{$script:FrontendConfirmAfterCheck=$false;$FrontendText.Text=$_.Exception.Message}
}
$FrontendButton.Add_Click({Request-LatestFrontendUpdate})
$script:CancelFrontendButton=New-Object Windows.Controls.Button;$CancelFrontendButton.Content='Cancelar atualizacao do launcher'
$CancelFrontendButton.Add_Click({if($script:FrontendProcess -and -not $script:FrontendProcess.HasExited){[IO.File]::WriteAllText((Join-Path $script:FrontendJob 'cancel'),'cancel');$FrontendText.Text='Cancelando atualizacao do launcher...'}})
$frontendTimer=New-Object Windows.Threading.DispatcherTimer;$frontendTimer.Interval=[TimeSpan]::FromMilliseconds(350)
function Update-FrontendProgressState {
    if(-not $script:FrontendProcess){return}
    try{
        $operationStatusPath=Join-Path $script:FrontendJob 'status.json'
        $result=Read-FrontendStatus $operationStatusPath
        if($null -eq $result){
            if($null -eq $script:FrontendReadBlockedAt){$script:FrontendReadBlockedAt=[DateTime]::UtcNow}
            if(([DateTime]::UtcNow-$script:FrontendReadBlockedAt).TotalSeconds -gt 15){throw 'Nao foi possivel ler o progresso por 15 segundos. Tente verificar novamente.'}
            return
        }
        $script:FrontendReadBlockedAt=$null
        $FrontendText.Text=$result.message
        if($result.state -eq 'working'){
            if($result.PSObject.Properties['total'] -and $result.total -gt 0){$FrontendProgress.IsIndeterminate=$false;$FrontendProgress.Value=[Math]::Min(100,100*$result.received/$result.total);$FrontendText.Text+=' '+[Math]::Floor($FrontendProgress.Value)+'%'}
            if($script:FrontendProcess.HasExited){throw 'Operacao interrompida. Tente novamente.'};return
        }
        if(-not $script:FrontendProcess.HasExited){return}
        $script:FrontendProcess=$null;$FrontendButton.IsEnabled=$true;$FrontendProgress.Visibility='Collapsed'
        if($result.state -eq 'available'){
            $script:FrontendPending=$true;$FrontendButton.Content='Instalar '+$result.version;$FrontendText.ToolTip=$result.notes
            $confirmNow=$script:FrontendConfirmAfterCheck;$script:FrontendConfirmAfterCheck=$false
            if($confirmNow){Confirm-LatestFrontendUpdate}
        }
        elseif($result.state -eq 'ready'){
            if($script:ActiveInstall){throw 'Um jogo esta sendo instalado. Atualizacao do launcher adiada.'}
            $m=Read-FrontendSignedManifest (Join-Path $script:FrontendJob 'update.json') (Join-Path $PSScriptRoot 'UpdatePublicKey.xml')
            $package=Join-Path $script:FrontendJob $m.fileName;Assert-FrontendPackage $package $m
            if(-not(Test-FrontendNewer (([IO.File]::ReadAllText((Join-Path $script:AppRoot 'versao.json'))|ConvertFrom-Json).version) $m.version)){throw 'Atualizacao antiga recusada.'}
            $args='--apply-update "'+$script:AppRoot+'" '+$PID
            $p=New-Object Diagnostics.ProcessStartInfo;$p.FileName=$package;$p.Arguments=$args;$p.UseShellExecute=$false
            [void][Diagnostics.Process]::Start($p);$window.Close()
        }else{$script:FrontendConfirmAfterCheck=$false;$script:FrontendPending=$false;$FrontendButton.Content='Verificar launcher'}
    }catch{$script:FrontendConfirmAfterCheck=$false;$FrontendText.Text=$_.Exception.Message;$script:FrontendProcess=$null;$FrontendButton.IsEnabled=$true;$FrontendProgress.Visibility='Collapsed'}
}
$frontendTimer.Add_Tick({Update-FrontendProgressState})
$frontendTimer.Start();$window.Add_Closed({$frontendTimer.Stop()})
if(-not $Verify){$window.Add_ContentRendered({try{Start-FrontendOperation 'Check'}catch{$FrontendText.Text='Atualizador indisponivel: '+$_.Exception.Message}})}
