# TarginoLauncher

### Recompilados by Central Arquivista

Interface comunitária independente para organizar e iniciar jogos recompilados no PC, com navegação por plataformas, teclado e controle.

**Desenvolvido por Targino Social Media. Créditos da base: projeto Central Arquivista.**

[Baixar a versão mais recente](https://github.com/timtompel/TarginoLauncher/releases/latest) · [Todas as versões](https://github.com/timtompel/TarginoLauncher/releases) · [Canal no Telegram](https://t.me/TarginoLauncher) · [Relatar um problema](https://github.com/timtompel/TarginoLauncher/issues)

## Manual e fontes

- [Manual do usuário em PDF](https://github.com/timtompel/TarginoLauncher/releases/download/v0.1.5/Manual-TarginoLauncher-Central-Arquivista.pdf).
- [Código do frontend](work/src) e [guia de desenvolvimento](work/README.md).
- Para compilar com os recursos binários e seus créditos, baixe o arquivo **Fontes.zip** na [release correspondente](https://github.com/timtompel/TarginoLauncher/releases/tag/v0.1.5).

A partir da 0.1.5, o launcher reconecta instalações gerenciadas após renomeação da pasta, quando o destino pode ser verificado. A operação cria backup e não move jogos. A opção de cancelar consulta/download fica em Configurações.

## Sobre o projeto

O TarginoLauncher é um frontend separado do programa original do Central Arquivista. Ele utiliza uma biblioteca compatível como fonte de catálogo e recursos, sem substituir a autoria ou modificar o código do programa original.

**O instalador não inclui jogos nem o programa original do Central Arquivista.** Uma instalação limpa precisa ser conectada à sua biblioteca existente. O launcher não é uma biblioteca autônoma de jogos.

O projeto continua em desenvolvimento. Compatibilidade com jogos, drivers e controles pode variar entre computadores.

## Recursos

- Biblioteca organizada por plataforma, com logos, capas e imagens ilustrativas.
- Jogos não instalados representados em tons de cinza.
- Ação principal contextual: **Jogar** quando instalado ou **Baixar** quando disponível para download.
- Download, extração e atualização de jogos pelo launcher, quando a fonte e as ferramentas da biblioteca forem compatíveis.
- Informação de versão instalada e dados locais de jogadores, quando disponíveis.
- Adição de jogos extras sem alterar o catálogo original.
- Navegação por teclado e controle; configuração de botões para controles USB/WinMM e suporte a XInput.
- Tela cheia com **F11**.
- Opções de renderizador somente para os ports em que houver suporte identificado — OpenGL ou renderização por software não estão disponíveis para todos os jogos.
- Atualização do próprio launcher por pacotes com manifesto assinado.
- Verificação da base e abertura do atualizador oficial do Central Arquivista, com confirmação.
- Desinstalação de jogos gerenciados pelo launcher e opção de backup de saves/configurações reconhecidos.
- **Configurações → Sobre**, com versão instalada, canal, créditos e links do projeto.

As sinopses online foram removidas da interface.

## Instalação

Requer Windows de 64 bits, Windows PowerShell 5.1 e .NET Framework compatível com os executáveis e a interface WPF. Os requisitos gráficos dependem de cada jogo; instalar o launcher não torna uma placa incompatível com Vulkan capaz de executar esses jogos.

1. Acesse a [última versão publicada](https://github.com/timtompel/TarginoLauncher/releases/latest).
2. Em **Assets**, baixe o arquivo `TarginoLauncher-Recompilados-X.Y.Z-Setup.exe`.
3. Instale em uma pasta própria, **separada da pasta do Central Arquivista original**.
4. Abra o launcher e use **Configurações → Escolher biblioteca** para selecionar a raiz da biblioteca original, que contém `Arquivismo` e `Jogos`.
5. Para downloads que utilizem Telegram, configure a conexão pela opção **Conectar Telegram**. O acesso depende da sua conta, das fontes cadastradas e das ferramentas disponíveis.

Não compartilhe arquivos de sessão, credenciais ou dados pessoais. Utilize apenas conteúdo ao qual você tenha direito de acesso.

### O que fica em cada pasta?

- **Biblioteca**: instalações de jogos gerenciadas pelo launcher.
- **Dados**: configurações, registros e outros dados locais.
- **Cache**: downloads temporários e arquivos de trabalho.
- **BackupsFrontend**: cópias de arquivos anteriores do launcher.

Jogos já existentes na biblioteca original não são movidos automaticamente para a Biblioteca do launcher.

## Atualizar o launcher

**Não é necessário desinstalar para atualizar.**

1. Abra **Configurações → Verificar / atualizar launcher**.
2. Aguarde a detecção de uma versão mais recente.
3. Selecione novamente a opção para instalar a versão oferecida e confirme as notas.
4. O launcher baixa e valida o pacote, fecha para a instalação e é reaberto após a conclusão.

O canal atual oferece apenas releases estáveis publicadas no GitHub. Prévias e rascunhos não são oferecidos automaticamente.

O manifesto `update.json` é assinado com **RSA-SHA256**. O cliente verifica a assinatura, a origem autorizada, o tamanho e o SHA256 do instalador antes de executá-lo. Isso **não é uma assinatura Authenticode de editor do Windows**: os executáveis ainda não possuem esse certificado.

As atualizações preservam Biblioteca, Dados, Cache e backups. O instalador mantém backup dos arquivos substituídos e realiza restauração em falhas de cópia tratáveis; isso não garante recuperação automática após queda de energia ou encerramento forçado.

### Se a atualização falhar

Clientes antigos podem exibir erro de arquivo em uso ao ler `status.json`. A correção foi publicada na **0.1.2**.

Feche e reabra o launcher e tente novamente. Se o erro impedir a atualização, baixe o instalador da [última release](https://github.com/timtompel/TarginoLauncher/releases/latest) e instale **na mesma pasta do launcher, sem desinstalar**.

A atualização do launcher, a atualização dos jogos e a atualização da base original são operações distintas. Para a base, o frontend abre o programa original e seu fluxo oficial de atualização.

## Desinstalação e preservação dos jogos

Ao desinstalar o launcher, a opção **Remover também os jogos da Biblioteca deste launcher** vem desmarcada.

- **Desmarcada:** os jogos são preservados.
- **Marcada:** a Biblioteca do launcher é enviada à Lixeira, incluindo saves que estejam dentro das pastas dos jogos.
- Jogos em pastas externas e o programa original do Central Arquivista não são removidos.
- Configurações e backups são preservados. Versões anteriores podem deixar pastas ou atalhos residuais.

A desinstalação individual de um jogo está disponível somente para instalações gerenciadas pelo launcher. A opção de backup preserva os saves e configurações reconhecidos, mas nem todos os formatos podem ser identificados. Saves fora da pasta do jogo não são alterados. A restauração desses backups não é automática.

**Faça backup dos seus saves importantes antes de remover jogos.**

## Créditos

- **Targino Social Media:** desenvolvimento da interface comunitária TarginoLauncher.
- **Central Arquivista:** créditos do programa original e da base utilizada pela biblioteca.
- **Artes de plataformas e fotos de controles:** autores, fontes e licenças indicados nos arquivos de créditos distribuídos em `Recursos/Plataformas` e `Recursos/Controles`.

As imagens de controles são referências ilustrativas. Drivers genéricos nem sempre permitem identificar a marca ou o modelo físico; nesses casos o launcher informa que o controle é genérico.

Este frontend é um projeto independente. A compatibilidade com a base não implica afiliação ou endosso do autor original. Nomes, marcas e recursos de terceiros pertencem aos respectivos titulares.

## Ajuda e sugestões

Abra uma [issue](https://github.com/timtompel/TarginoLauncher/issues) informando a versão do launcher, o que você tentou fazer e a mensagem de erro. Se possível, inclua uma captura de tela, **sem expor credenciais ou dados de sessão**.

Acompanhe o projeto no [Telegram](https://t.me/TarginoLauncher).
