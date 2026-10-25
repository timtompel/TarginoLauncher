# Alterações da 0.1.11 (sobre a 0.1.10)

Resumo completo do que foi feito. Tudo foi revisado por leitura de código; os testes automáticos e o build rodaram no Windows do autor (veja "Validação" no fim).

## 1. Correções de bugs

| # | Problema | O que mudou | Arquivo |
|---|----------|-------------|---------|
| 1 | Se o registro de um jogo recém-instalado falhasse, a operação ficava "ativa" repetindo o erro a cada segundo e bloqueava novos downloads | A interface é sempre liberada; o erro aparece uma vez ("Jogo instalado, mas o registro falhou") | `CentralArquivista.ps1` (timer de instalação) |
| 2 | `instalados.json` corrompido derrubava a biblioteca inteira | Usa a cópia `.bak`, avisa o usuário e se auto-repara; ao instalar com o arquivo corrompido, a `.bak` boa não é sobrescrita (o corrompido vai para `.corrompido-<guid>`) | `Catalog.ps1` (`Read-CentralJsonOrBackup`), `PortablePaths.ps1`, `GameVersions.ps1`, `CentralArquivista.ps1` |
| 3 | Leitura do `status.json` do worker falhava quando o arquivo estava sendo trocado | `Read-SharedJson` tolera arquivo em uso e tenta no próximo ciclo | `Catalog.ps1`, `CentralArquivista.ps1` |
| 4 | Argumentos de processo montados por concatenação quebravam com raiz de unidade/espaço e barra final | `ConvertTo-WindowsArgument` único (argumento vazio vira `""`) usado no worker de instalação, base, login, atualizador do launcher e `--apply-update` | `Catalog.ps1`, `CentralArquivista.ps1`, `FrontendUpdateUI.ps1` |
| 5 | `Start-CatalogGame` só era protegido contra alvos que não fossem `.exe` no botão Jogar | A checagem passou para dentro de `Start-CatalogGame` | `Catalog.ps1` |

## 2. Telegram e relógio do Windows

- Causa real de um erro observado: relógio do Windows adiantado → o Telegram responde `msg_id too high` e o `tdl` fica reconectando sem mostrar QR.
- `Run-Tool` reconhece `msg_id too high/low` e `bad_msg_notification` do `tdl`.
- `Invoke-Tdl` tenta **uma vez** de novo com `--ntp pool.ntp.org`; se falhar, mostra mensagem clara (horário automático, fuso de Brasília, "Sincronizar agora"). Usado na consulta do post e no download. Fora desse erro nada muda. *A opção `--ntp` do tdl não foi validada em campo; se não existir, o resultado é a mensagem clara.*
- Tela **Conectar Telegram** mede o relógio contra `time.windows.com` (NTP/UDP 123) e avisa antes do QR se a diferença passar de 20 s (se a medição falhar, mostra só uma dica).
- Arquivos: `InstallWorker.ps1`, `ConnectTelegram.ps1`.

## 3. Fila de downloads (novo)

- Um download por vez, em ordem (FIFO). Com download em andamento, **Baixar** e **Atualizar jogo** adicionam à fila.
- Não aceita duplicados nem o jogo que já está baixando. Botão muda para "Adicionar à fila" / "Baixando...".
- Ao terminar, o próximo começa sozinho. Falha em um item não para a fila. Resumo (Instalado/Falhou) ao final de lotes; a pergunta "Jogar agora" só aparece sem fila.
- Status mostra "Fila: N aguardando". **Configurações → Fila de downloads (N)** remove itens ou limpa a fila.
- Cancelar interrompe só o download atual. A fila é só em memória (fechar o launcher a limpa). Desinstalar jogo e aplicar atualização do launcher ficam bloqueados enquanto houver download ou fila.
- Arquivos: `DownloadQueue.ps1` (lógica pura, novo), `CentralArquivista.ps1` (`Start-GameDownload`, `Open-DownloadSource`, `Start-NextQueuedDownload`, timer), `OrganizedUI.ps1` (menu).

## 4. Desempenho da interface

- `Refresh-List` não roda mais 2–3 vezes a cada carga do catálogo (supressão durante a reconstrução do filtro de plataforma).
- Busca com pausa de 250 ms ao digitar; mudanças feitas pelo programa continuam imediatas (não perde o foco do controle).
- Miniaturas decodificadas uma vez por capa/estado (cache limpo a cada `Load-Catalog`).

## 5. Cache, rede e atualização do launcher

- `Clear-StaleLauncherCache` roda ao abrir: remove verificações do launcher/base com mais de 2 dias e operações de jogo **não concluídas** paradas há mais de 30 dias. Nunca toca em Biblioteca, Dados, saves, operações concluídas (guardam backup de recuperação) nem em pastas com links.
- Verificação automática de atualização do launcher espera 3 horas entre aberturas (limite de 60 requisições/hora/IP da API do GitHub). O botão manual sempre consulta. HTTP 403/429 mostra mensagem clara. Novo arquivo `Dados\ultima-verificacao-launcher.txt` (UTC).
- `Setup.cs`: mantém só os 5 backups mais recentes em `BackupsFrontend` (apenas pastas no padrão do Setup, sem links).

## 6. Interface e projeto

- Foco por teclado/controle visível nos botões (brilho verde); removido o retângulo pontilhado padrão (`MainWindow.xaml`).
- Tooltip no status com o texto completo; item **Copiar última mensagem / erro** em Configurações.
- BOM UTF-8 em `Catalog.ps1`, `CentralArquivista.ps1`, `OrganizedUI.ps1` e `.editorconfig` (utf-8-bom para ps1/cs/xaml): o PowerShell 5.1 lê sem BOM como ANSI.
- Versão `0.1.11` em `project.json`; notas em `installer/NOTAS-0.1.11.txt`; README e LEIA-ME atualizados.

## 7. Testes novos ou ampliados

- `DownloadQueue.Tests.ps1` (novo): ordem FIFO, duplicados, item ativo, posição, remoção.
- `Resilience.Tests.ps1` (novo): argumentos, fallback para `.bak`, auto-reparo, leitura compartilhada, recusa de alvo não-.exe, retenção segura de cache.
- `InstallErrors.Tests.ps1`: casos de relógio do Telegram com `tdl` falso (detecção, nova tentativa com `--ntp`, mensagem final).

## 8. Arquivos alterados

Novos: `src/DownloadQueue.ps1`, `tests/DownloadQueue.Tests.ps1`, `tests/Resilience.Tests.ps1`, `.editorconfig`, `CHANGELOG.md`, `installer/NOTAS-0.1.11.txt`.
Alterados: `installer/Setup.cs`, `src/Catalog.ps1`, `src/CentralArquivista.ps1`, `src/ConnectTelegram.ps1`, `src/FrontendUpdateUI.ps1`, `src/FrontendUpdateWorker.ps1`, `src/GameVersions.ps1`, `src/Input.ps1`, `src/InstallCleanup.ps1`, `src/InstallWorker.ps1`, `src/MainWindow.xaml`, `src/OrganizedUI.ps1`, `src/PortablePaths.ps1`, `tests/InstallErrors.Tests.ps1`, `project.json`, `README.md`.
O Bootstrap (`StableBootstrap.cs`, `Build-StableBootstrap.ps1`) **não foi alterado**; ele é recompilado pelo `Build-Distribution.ps1` junto com a versão estável.

## 9. Não feito (decisões ou risco)

- Regra de arquivos preservados na atualização de jogos (`.json/.ini/.cfg/.toml/mods` existentes nunca são sobrescritos) — precisa de decisão do autor.
- Segunda chave de assinatura, certificado Authenticode, imagens menores, acentos nos textos da interface, Pester/CI, SDL2 para controles, fila persistente entre execuções.

## 10. Validação

- 24 testes `tests/*.Tests.ps1` (exceto `OrganizedUI` e `UpdateCycle`) passaram no Windows do autor, incluindo os novos.
- Build e `Test-Distribution.ps1` passaram com o código da etapa anterior (sem a fila).
- Pendente antes de publicar: build e `Test-Distribution.ps1` com a versão final e teste manual da fila (interface).
