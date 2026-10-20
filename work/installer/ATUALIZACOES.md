# Publicacao de atualizacoes do TarginoLauncher

Repositorio: https://github.com/timtompel/TarginoLauncher
Anuncios: https://t.me/TarginoLauncher

O cliente consulta a API publica `releases/latest`, sem login/token. Nao recebe
previas nem rascunhos. O manifesto `update.json` e assinado com RSA-SHA256 de
3072 bits; a chave publica e incluida no cliente. Tamanho e SHA256 do instalador
estao dentro da assinatura. Nenhuma chave privada deve ir ao GitHub ou Telegram.

## Preparar (nao publica nada)

1. Execute `Prepare-StableRelease.ps1 -Initialize` uma unica vez. A chave privada
   fica em `%LOCALAPPDATA%\TarginoLauncher-Publisher\signing-key.dpapi`, protegida
   pelo Windows para o usuario atual. Nao perca o perfil Windows: copiar somente
   esse arquivo para outro computador nao e um backup portavel da chave.
2. Revise codigo, creditos/licencas e testes. Execute `Build-Distribution.ps1`
   sem argumentos para gerar a previa de testes. Nao marque esta previa estavel.
3. Somente depois de aprovar, compile uma versao x.y.z com
   `Build-Distribution.ps1 -Version X.Y.Z`. O codigo nao decide estabilidade por voce.
4. Crie notas UTF-8 e execute:
   `Prepare-StableRelease.ps1 -SetupPath CAMINHO_DO_SETUP -Version X.Y.Z -NotesPath CAMINHO_DAS_NOTAS -OutputDirectory PASTA_NOVA`
5. No GitHub Releases, crie primeiro um rascunho com tag `vX.Y.Z`, anexando o
   instalador e o `update.json` gerado. Revise tudo antes de publicar como estavel.
6. Publique o aviso no Telegram somente depois de validar o download publico.

## Aplicacao

O usuario confirma a versao/notas. O download mostra progresso. O instalador e
validado antes de executar, espera o launcher fechar e reconhece a pasta pelo
`frontend.manifest`. Mantem um bloqueio enquanto substitui arquivos permitidos,
guarda os antigos em `BackupsFrontend` e restaura os copiados em falha tratavel.
Dados, Cache, Biblioteca e Central original nao integram o pacote. Atualizacoes
de jogos/base sao funcoes distintas. A primeira instalacao precisa usar o setup.

Queda de energia ou encerramento forcado durante copia nao garantem rollback
automatico; backups permanecem para recuperacao. Nao e um atualizador transacional
resistente a queda de energia. Arquivos antigos nao incluidos ficam no disco.

## Limites e validacao

Limite de instalador: 64 MiB. Limite de arquivos extraidos: 64 MiB. Erros de rede
nao impedem abrir a biblioteca. O projeto nao incorpora telemetria, token ou senha.
O teste de release real ponta a ponta depende de uma release assinada publicada;
os testes locais nao substituem essa validacao. Nenhuma release e publicada pelos scripts.
