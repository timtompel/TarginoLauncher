# Fila do projeto

## Prioridade atual

- Concluir testes da correcao de extracao UnRAR codigo 9 (caminhos longos), com erros diferenciados por ferramenta e retomada do mesmo download.
- Publicar correcao e limpeza de downloads/extracoes concluidas pelo updater. Nao copiar arquivos manualmente para a instalacao em uso.
- Entregar arte de boas-vindas do bot, no tamanho aceito pelo BotFather.

## Bot TarginoLauncherAvisosBot: escopo aprovado para estudo

Avisos de releases ja configurados. Os itens abaixo sao propostas na fila, NAO funcionalidades implementadas nem configuracoes ativadas.

1. Perfil: avatar, nome, resumo e descricao; imagem de boas-vindas.
2. Comandos propostos: /start (apresentacao), /baixar (Setup e bootstrap oficiais), /atualizar (orientacoes e ultima release), /manual (manual), /arquivista (credito e canal da base), /suporte (como relatar erros sem credenciais).
   Cadastrar comandos no BotFather nao implementa respostas: sera necessario um handler hospedado e testar antes de anunciar.
3. Menu: avaliar um botao para o site publico existente, com download, manual e primeiros passos. Nao ativar Mini App sem avaliar necessidade, hospedagem e privacidade.
4. Compartilhamento inline: avaliar futuramente apenas links oficiais do launcher/manual; nao distribuir jogos ou arquivos privados.
5. Serverless: estudar disponibilidade, limites e custos antes de escolher hospedagem; nao solicitar acesso beta ou contratar plano automaticamente.

## Fora da prioridade / manter desativado

- Login Widget / OpenID Connect: nao ha requisito atual de conta no site; nao confundir login do bot com a sessao pessoal usada pelo downloader.
- Gerenciamento de bots, modo secretaria, acesso a conversas e comunicacao entre bots: fora do escopo; nao ampliar permissoes.
- Guard Mode e moderacao: somente se houver necessidade e autorizacao separada.
- Games HTML5: nao sao os jogos Windows do launcher; nao adicionar como se fosse execucao da biblioteca pelo Telegram.

## Limites

- Interface comunitaria independente; manter creditos ao Central Arquivista.
- Nao incluir jogos, sessoes Telegram, tokens ou mensagens privadas nos arquivos publicados.
- Nenhuma configuracao de BotFather foi alterada ao criar esta fila.
