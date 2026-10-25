$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\src\DownloadQueue.ps1')
function Assert($Condition,[string]$Message){if(-not $Condition){throw $Message}}
$queue=New-DownloadQueue
Assert ($queue.Count -eq 0) 'Fila nova deve estar vazia.'
Assert ($null -eq (Get-NextDownloadQueueItem $queue)) 'Fila vazia deve devolver $null.'
Assert ((Add-DownloadQueueItem $queue 'jogo-a' 'Jogo A' 'jogo-a') -eq 'active') 'Jogo em download nao pode entrar na fila.'
Assert ($queue.Count -eq 0) 'Item ativo foi enfileirado.'
Assert ((Add-DownloadQueueItem $queue 'jogo-b' 'Jogo B' 'jogo-a') -eq 'added') 'Primeiro item deveria entrar.'
Assert ((Add-DownloadQueueItem $queue 'jogo-c' 'Jogo C' 'jogo-a') -eq 'added') 'Segundo item deveria entrar.'
Assert ((Add-DownloadQueueItem $queue 'jogo-b' 'Jogo B' 'jogo-a') -eq 'queued') 'Duplicado deveria ser recusado.'
Assert ((Add-DownloadQueueItem $queue 'JOGO-B' 'Jogo B' 'jogo-a') -eq 'added') 'Ids diferem por caixa: tratados como jogos distintos (mesma regra do restante do launcher).'
Assert ($queue.Count -eq 3) 'Fila deveria ter 3 itens.'
Assert ((Get-DownloadQueuePosition $queue 'jogo-c') -eq 2) 'Posicao de jogo-c deveria ser 2.'
Assert ((Get-DownloadQueuePosition $queue 'nao-existe') -eq 0) 'Posicao de item ausente deveria ser 0.'
Assert (Remove-DownloadQueueItem $queue 'JOGO-B') 'Remocao de item existente falhou.'
Assert (-not (Remove-DownloadQueueItem $queue 'nao-existe')) 'Remocao de item inexistente deveria retornar falso.'
$first=Get-NextDownloadQueueItem $queue
Assert ($first.id -eq 'jogo-b' -and $first.title -eq 'Jogo B') 'Ordem FIFO quebrada (primeiro).'
$second=Get-NextDownloadQueueItem $queue
Assert ($second.id -eq 'jogo-c') 'Ordem FIFO quebrada (segundo).'
Assert ($queue.Count -eq 0) 'Fila deveria esvaziar.'
$noTitle=New-DownloadQueue
[void](Add-DownloadQueueItem $noTitle 'sem-titulo' '' '')
Assert ((Get-NextDownloadQueueItem $noTitle).title -eq 'sem-titulo') 'Sem titulo deveria usar o id.'
'PASS: fila de downloads FIFO, sem duplicados, sem enfileirar o jogo ativo, remocao e retirada corretas.'
