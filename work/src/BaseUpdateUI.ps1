. (Join-Path $PSScriptRoot 'BaseUpdate.ps1')
$script:BaseLatestResult=$null;$script:BaseLatestRoot='';$script:OfficialBaseUpdate=$null
function Get-OfficialBaseLaunchInfo([string]$Root){
    $context=Get-BaseUpdateContext $Root
    $url=$null
    if(-not [Uri]::TryCreate($context.url,[UriKind]::Absolute,[ref]$url) -or $url.Scheme -ne 'https' -or $url.UserInfo){throw 'Endereco de atualizacao da base invalido.'}
    $rootPath=[IO.Path]::GetFullPath($Root)
    $scriptPath=Join-Path $rootPath 'Arquivismo\Launcher.ps1'
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=Join-Path $PSHOME 'powershell.exe'
    $info.Arguments='-NoProfile -STA -ExecutionPolicy Bypass -File "'+$scriptPath+'"'
    $info.WorkingDirectory=$rootPath;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
    [pscustomobject]@{info=$info;marker=$context.marker;url=$context.url;root=$rootPath}
}
$script:OfficialBaseUpdateButton=New-Object Windows.Controls.Button
$OfficialBaseUpdateButton.Add_Click({try{
    if($script:ActiveInstall -or $script:OfficialBaseUpdate -or ($script:FrontendProcess -and -not $script:FrontendProcess.HasExited)){throw 'Aguarde as outras operacoes terminarem.'}
    if(-not $script:BaseLatestResult -or $script:BaseLatestResult.state -ne 'changed' -or $script:BaseLatestRoot -ne $script:GamesRoot){throw 'Verifique a base primeiro. Nao ha atualizacao confirmada para esta biblioteca.'}
    $launch=Get-OfficialBaseLaunchInfo $script:GamesRoot
    $message="Abrir o Central original para aplicar a atualizacao oficial?`n`nEle usara o atualizador proprio e pode pedir permissoes para seus componentes. Nosso launcher nao extraira nem substituira arquivos da base.`n`nOrigem configurada no Central:`n"+$launch.url+"`n`nA biblioteca ficara temporariamente bloqueada durante a atualizacao."
    if([Windows.MessageBox]::Show($window,$message,'Atualizar Central original','YesNo','Question') -ne 'Yes'){return}
    $process=[Diagnostics.Process]::Start($launch.info)
    $script:OfficialBaseUpdate=@{process=$process;root=$launch.root;marker=$launch.marker;started=[DateTime]::UtcNow}
    $LibraryGrid.IsEnabled=$false;$settings.IsEnabled=$false;$ChooseRoot.IsEnabled=$false
    $BaseUpdateText.Text='Atualizando pelo Central original. Acompanhe a janela oficial.'
}catch{[void][Windows.MessageBox]::Show($window,$_.Exception.Message,'Atualizacao da base')}})
$officialTimer=New-Object Windows.Threading.DispatcherTimer;$officialTimer.Interval=[TimeSpan]::FromSeconds(2)
$officialTimer.Add_Tick({
    if(-not $script:OfficialBaseUpdate){return}
    $operation=$script:OfficialBaseUpdate
    try{
        $markerFile=Join-Path $operation.root 'Arquivismo\Dados\atualizacao.json';$marker=''
        if(Test-Path -LiteralPath $markerFile){$state=Read-CentralJson $markerFile;if($state.PSObject.Properties['ETag']){$marker=[string]$state.ETag}}
        $updated=($marker -and $marker -cne $operation.marker)
        if($updated -or $operation.process.HasExited -or ([DateTime]::UtcNow-$operation.started).TotalMinutes -gt 15){
            $script:OfficialBaseUpdate=$null;$LibraryGrid.IsEnabled=$true;$settings.IsEnabled=$true;$ChooseRoot.IsEnabled=$true
            if($updated){Load-Catalog;Set-Status 'Atualizacao oficial concluida; catalogo recarregado.'}
            else{Start-BaseUpdateCheck;Set-Status 'Confira o resultado na janela do Central original. Nenhuma atualizacao foi confirmada aqui.'}
        }
    }catch{$BaseUpdateText.Text='Aguardando a conclusao da atualizacao oficial...'}
})
$officialTimer.Start();$window.Add_Closed({$officialTimer.Stop()})
