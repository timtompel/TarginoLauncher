Set-StrictMode -Version Latest
# Fila de downloads em memoria: um download por vez, os demais aguardam aqui.
# Logica pura (sem interface) para poder ser testada isoladamente.

function New-DownloadQueue {
    # A virgula impede o PowerShell de "desenrolar" a lista ao retornar.
    return ,(New-Object 'Collections.Generic.List[object]')
}

# Retorna 'active' (ja esta baixando), 'queued' (ja esta na fila) ou 'added'.
function Add-DownloadQueueItem {
    param([Parameter(Mandatory)]$Queue,[Parameter(Mandatory)][string]$Id,[string]$Title,[string]$ActiveId)
    if ($ActiveId -and $Id -ceq $ActiveId) { return 'active' }
    foreach ($item in $Queue) { if ($item.id -ceq $Id) { return 'queued' } }
    $Queue.Add(@{ id = $Id; title = $(if ($Title) { $Title } else { $Id }) })
    return 'added'
}

# Posicao (1 = proximo) de um id na fila; 0 se nao estiver.
function Get-DownloadQueuePosition {
    param([Parameter(Mandatory)]$Queue,[Parameter(Mandatory)][string]$Id)
    $position = 0
    foreach ($item in $Queue) { $position++; if ($item.id -ceq $Id) { return $position } }
    return 0
}

function Remove-DownloadQueueItem {
    param([Parameter(Mandatory)]$Queue,[Parameter(Mandatory)][string]$Id)
    for ($i = 0; $i -lt $Queue.Count; $i++) {
        if ($Queue[$i].id -ceq $Id) { $Queue.RemoveAt($i); return $true }
    }
    return $false
}

# Retira e devolve o proximo item (ou $null se a fila estiver vazia).
function Get-NextDownloadQueueItem {
    param([Parameter(Mandatory)]$Queue)
    if ($Queue.Count -eq 0) { return $null }
    $item = $Queue[0]
    $Queue.RemoveAt(0)
    return $item
}
