# Desenvolvimento do TarginoLauncher

Interface comunitária independente para bibliotecas do Central Arquivista. Não inclui jogos, credenciais ou o programa original.
O launcher cria uma biblioteca própria de instalações em Biblioteca, separada do Central original. Os jogos baixados pelo frontend ficam nessa pasta; conectar uma base não copia automaticamente os jogos existentes.

## Organização

- `src/`: interface WPF, lógica do catálogo, downloads, atualização e caminhos portáveis.
- `installer/`: instalador, desinstalador, compilação e assinatura de releases.
- `tests/`: testes sintéticos; a maioria cria fixtures isoladas, sem executar jogos reais.
- `project.json`: fonte da versão padrão. Os números das assemblies e do instalador são gerados na compilação.
- `distribution-assets/`: recursos binários com créditos próprios; fornecidos no pacote Fontes da release correspondente.
- `catalog.schema.json`: contrato do catálogo complementar.

O XAML principal está em `src/MainWindow.xaml`; não há mais camadas de substituição dos temas anteriores. As consultas de sinopse foram removidas. Informações locais já existentes de jogadores continuam sendo lidas.

## Compilar

Use Windows x64, Windows PowerShell 5.1 e o compilador C# do .NET Framework. Não é necessário Visual Studio para o build atual.

Extraia o pacote `TarginoLauncher-Recompilados-X.Y.Z-Fontes.zip` da release para obter a estrutura `work/`, inclusive os recursos binários. Os textos no repositório acompanham essa estrutura, mas não substituem o pacote de recursos.

A partir da pasta que contém `work/`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File work/installer/Build-Distribution.ps1
```

O resultado fica em `outputs/`. A versão é lida de `work/project.json`. Para um build de laboratório, use `-Version X.Y.Z-preview.N`. Não renomeie uma prévia para estável.

Os scripts opcionais de conversão de imagem usam Node.js e `sharp` instalado separadamente. Não são necessários para compilar com os recursos já preparados.

## Testar

Execute cada arquivo `tests/*.Tests.ps1` em um processo PowerShell separado, com `-STA` para testes WPF. `UpdateCycle.Tests.ps1` e `installer/Test-Distribution.ps1` exigem `-SetupPath`. `OrganizedUI.Tests.ps1` exige `-AppRoot` e lê um catálogo conectado: não o execute contra dados desconhecidos.

Testes adicionados na 0.1.11: `DownloadQueue.Tests.ps1` (fila de downloads), `Resilience.Tests.ps1` (argumentos de processo, JSON com copia de seguranca, leitura compartilhada, retencao de cache) e novos casos em `InstallErrors.Tests.ps1` (relogio do Telegram). A interface da fila so e coberta por teste manual.

`--test-install` usa o motor real de instalação sem criar atalhos ou registro do Windows. `--test-apply-update` usa a espera do processo, instalação e reabertura de verificação WPF, sem registrar o aplicativo do teste como a instalação do usuário.

Fixtures incluem apenas executáveis sintéticos. Testes de rede usam um transporte simulado para interrupção, timeout, cancelamento e limites. Não simular falta de espaço enchendo o disco do usuário.

Os testes isolados neste computador não substituem uma VM limpa ou outro computador, nem validam todos os jogos, drivers ou contas Telegram.

## Segurança da publicação

O cliente confia em `src/UpdatePublicKey.xml`. A chave privada DPAPI do publicador fica fora do projeto. Não a publique, não a substitua e não a copie para o pacote.

`Publisher.Tests.ps1` gera chaves efêmeras e não acessa a chave privada de produção. Releases reais usam `Prepare-StableRelease.ps1`, que valida versão, tamanho, SHA256 e assinatura. O manifesto RSA não é um certificado Authenticode.

Não publique `Dados/`, `Cache/`, `Biblioteca/`, `BackupsFrontend/`, fixtures, sessões do Telegram ou logs pessoais. Confira os créditos de imagens distribuídas e mantenha-os no pacote.

## Dados e portabilidade

Após renomear a pasta do launcher, registros de jogos antigos são reancorados apenas quando o caminho anterior não existe, era filho direto de Biblioteca com o mesmo identificador e o executável está presente no destino atual. A migração cria backup e não move jogos. Registros externos não são reescritos.

Atalhos e cadastro do Windows precisam apontar para a nova pasta. O instalador os repara ao registrar uma atualização. O desinstalador preserva arquivos pessoais e não apaga diretórios desconhecidos só para deixar a pasta vazia.

## Créditos e licenciamento

Frontend por Targino Social Media. Créditos da base ao projeto Central Arquivista. Não há código do programa original incluído neste repositório.

Não foi escolhida uma licença geral de reutilização do código. Os recursos de terceiros conservam suas licenças e atribuições próprias; consulte os créditos no pacote Fontes. Não presumir uma licença única para todo o conteúdo.

