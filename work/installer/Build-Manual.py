"""Manual do usuário, sem dados pessoais ou capturas da biblioteca local."""
from pathlib import Path
from xml.sax.saxutils import escape
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor, white
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.utils import ImageReader
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output' / 'pdf' / 'Manual-TarginoLauncher-Central-Arquivista.pdf'
OUT.parent.mkdir(parents=True, exist_ok=True)
pdfmetrics.registerFont(TTFont('Segoe', 'C:/Windows/Fonts/segoeui.ttf'))
pdfmetrics.registerFont(TTFont('SegoeBold', 'C:/Windows/Fonts/segoeuib.ttf'))
pdfmetrics.registerFontFamily('Segoe', normal='Segoe', bold='SegoeBold')
W, H = 595.28, 841.89
INK, MUTED, GREEN, NAVY = map(HexColor, ['#172520', '#54635e', '#168c34', '#11272f'])
c = canvas.Canvas(str(OUT), pagesize=(W, H))
c.setTitle('Manual do usuário - TarginoLauncher-Central Arquivista')
c.setAuthor('Targino Social Media')
style = ParagraphStyle('body', fontName='Segoe', fontSize=10.7, leading=16.5, textColor=INK)
small = ParagraphStyle('small', parent=style, fontSize=9, leading=13, textColor=MUTED)
page = 0
y = 0

def para(text, gap=12, kind=None):
    global y
    p = Paragraph(text, kind or style)
    _, height = p.wrap(W - 100, H)
    if y - height < 66:
        raise RuntimeError(f'Texto ultrapassa página {page}: {text[:60]}')
    p.drawOn(c, 50, y - height)
    y -= height + gap

def heading(text):
    global y
    y -= 6
    c.setFont('SegoeBold', 13)
    c.setFillColor(GREEN)
    c.drawString(50, y, text)
    y -= 23

def note(title, text):
    global y
    p = Paragraph(f'<b>{title}</b><br/>{text}', style)
    _, height = p.wrap(W - 130, H)
    box = height + 26
    if y - box < 66:
        raise RuntimeError(f'Caixa ultrapassa página {page}')
    c.setFillColor(HexColor('#edf4ef'))
    c.roundRect(50, y-box, W-100, box, 8, fill=1, stroke=0)
    c.setFillColor(GREEN)
    c.rect(50, y-box+8, 3, box-16, fill=1, stroke=0)
    p.drawOn(c, 65, y-13-height)
    y -= box + 18

def start(title, subtitle):
    global page, y
    if page:
        footer(); c.showPage()
    page += 1
    c.setFillColor(NAVY); c.rect(0, H-71, W, 71, fill=1, stroke=0)
    c.setFont('SegoeBold', 12); c.setFillColor(white)
    c.drawString(50, H-35, 'TarginoLauncher-Central Arquivista')
    c.setFont('Segoe', 9); c.drawString(50, H-53, 'MANUAL DO USUÁRIO | versão de referência 0.1.5')
    c.setFillColor(INK); c.setFont('SegoeBold', 24); c.drawString(50, H-116, title)
    c.setFont('Segoe', 11); c.setFillColor(MUTED); c.drawString(50, H-138, subtitle)
    y = H - 173

def footer():
    c.setStrokeColor(HexColor('#d8e2dc')); c.line(50, 48, W-50, 48)
    c.setFont('Segoe', 8); c.setFillColor(MUTED)
    c.drawString(50, 32, 'Targino Social Media | Créditos da base: projeto Central Arquivista')
    c.drawRightString(W-50, 32, f'{page:02d} / 08')

start('Seu primeiro acesso', 'Instalar, conectar a biblioteca e começar a usar.')
banner = ROOT / 'work' / 'distribution-assets' / 'banner.png'
image = ImageReader(str(banner)); iw, ih = image.getSize()
height = (W-100) * ih / iw
c.drawImage(image, 50, y-height, width=W-100, height=height, mask='auto')
y -= height + 25
para('<b>Uma interface comunitária para organizar seus jogos recompilados no PC.</b> Navegue por plataformas, use teclado ou controle e acompanhe instalações e atualizações em um só lugar.')
note('O que este instalador entrega?', 'Somente o frontend TarginoLauncher. Ele não inclui jogos, contas, catálogo pessoal nem o programa original do Central Arquivista. Conecte sua biblioteca existente no primeiro uso.')
para('Desenvolvimento da interface: <b>Targino Social Media</b>.<br/>Créditos do programa e da base original: <b>projeto Central Arquivista</b>.', kind=small)
para('Edição: 20/10/2026. Guia baseado na versão 0.1.5. O projeto continua em desenvolvimento; nomes e posições podem mudar em versões futuras.', kind=small)

start('01. Instalação', 'Comece em uma pasta separada do programa original.')
heading('Antes de começar')
para('Ambiente alvo: Windows x64, Windows PowerShell 5.1 e .NET Framework com suporte à interface WPF. Os testes desta entrega foram feitos no mesmo computador Windows do desenvolvimento, não em todos os modelos de PC.')
para('É preciso internet para baixar atualizações e pacotes. Cada jogo possui requisitos próprios de placa de vídeo e drivers. O launcher não instala drivers e não cria suporte a Vulkan em uma placa incompatível.')
heading('Passo a passo')
para('<b>1.</b> Acesse <link href="https://github.com/timtompel/TarginoLauncher/releases/latest" color="#168c34">a release mais recente no GitHub</link>. Em Assets, baixe o arquivo terminado em <b>Setup.exe</b>.')
para('<b>2.</b> Execute o instalador e escolha uma pasta só para o launcher. Não instale dentro da pasta que contém o Central Arquivista original.')
para('<b>3.</b> Conclua a instalação e escolha abrir o launcher. Use o executável ou o atalho com o avatar Targino.')
para('<b>4.</b> Em <b>Configurações &gt; Escolher biblioteca</b>, selecione a raiz da biblioteca original: a pasta que contém <b>Arquivismo</b> e <b>Jogos</b>. Não selecione apenas Dados ou uma pasta de jogo.')
para('<b>5.</b> Volte à biblioteca, escolha uma plataforma e entre nos jogos. A opção <b>Recarregar catálogo</b> atualiza a lista quando necessário.')
note('Biblioteca vazia?', 'Uma instalação nova não carrega automaticamente os arquivos pessoais de quem desenvolveu o launcher. Confira a pasta selecionada e se o catálogo existe na biblioteca original.')

start('02. Biblioteca e jogos', 'Entenda a diferença entre disponível e instalado.')
heading('Plataformas e pesquisa')
para('Na tela inicial, selecione o logo de uma plataforma. A próxima tela mostra os jogos e a ficha à direita. Use <b>Todas as plataformas</b> para consultar o conjunto completo. A busca filtra os títulos; Esc/B volta à tela de plataformas.')
heading('O botão principal')
para('<b>Jogar:</b> o launcher encontrou o executável da instalação. Ao confirmar, ele inicia o jogo com a pasta de trabalho correspondente.')
para('<b>Baixar:</b> o jogo não foi encontrado instalado. A ação depende de uma fonte cadastrada, ferramentas compatíveis da base e acesso à mensagem/pacote. As capas em cinza ajudam a reconhecer os não instalados.')
heading('Downloads pelo Telegram')
para('Abra <b>Configurações &gt; Conectar Telegram</b> quando a biblioteca exigir autenticação. Conecte sua própria conta seguindo a janela de autenticação. Não envie senha, código de acesso ou arquivo de sessão para terceiros.')
para('Quando houver suporte, o launcher consulta a versão, baixa o pacote, verifica e extrai em uma área de trabalho. Novas instalações gerenciadas ficam na pasta <b>Biblioteca</b> do launcher. A instalação original não é movida automaticamente.')
para('Acompanhe o texto e a barra de progresso. Ao concluir o registro da instalação, você poderá escolher abrir o jogo ou voltar à biblioteca. Se a fonte estiver indisponível ou o executável esperado não for encontrado, confira a mensagem de erro antes de repetir.')
note('Atenção aos saves', 'A preservação depende dos caminhos e formatos reconhecidos. Guarde uma cópia própria dos saves importantes. Não considere todo arquivo de configuração automaticamente compatível com uma nova versão do jogo.')

start('03. Teclado e controle', 'Navegar sem depender do mouse.')
for title, text in [
 ('Navegação', '<b>Setas ou direcional:</b> mover seleção. <b>Enter/A/Start:</b> confirmar. <b>Esc/B:</b> voltar. <b>D/X:</b> abrir ficha. <b>F:</b> buscar. <b>F11:</b> alternar tela cheia.'),
 ('Controles USB e adaptadores', 'Abra <b>Configurações &gt; Configurar controle</b>. A tela mostra o driver detectado, os botões pressionados e uma foto ilustrativa. Nem todo adaptador informa a marca ou o modelo físico.'),
 ('Mapear um botão', '<b>1.</b> Clique no campo da ação desejada.<br/><b>2.</b> Solte os botões do controle.<br/><b>3.</b> Pressione apenas o botão desejado.<br/><b>4.</b> Confira o número no campo e repita para outras ações.<br/><b>5.</b> Clique em <b>Salvar controle</b>.'),
 ('Evitar ações duplicadas', 'Se um botão já estiver atribuído a outra ação, as atribuições são trocadas. Durante a captura, Voltar e Confirmar não fecham nem salvam a tela por conta própria. Também é possível digitar os índices manualmente.'),
 ('Xbox / XInput', 'O mapeamento lógico de A/B/X/Y e Start é automático em XInput. Os campos numéricos são destinados aos controles USB/WinMM. Select + Y pode abrir a busca virtual conforme o controle e o mapeamento.')]:
    heading(title); para(text)
note('Não reconheceu o controle?', 'Confira a conexão e o reconhecimento pelo Windows. Um nome genérico do driver não prova que o controle é Sony, Xbox, SNES ou Mega Drive; a foto é apenas referência.')

start('04. Atualizações', 'Três operações diferentes, cada uma com seu papel.')
heading('Atualizar o próprio launcher')
para('<b>1.</b> Abra <b>Configurações &gt; Verificar / atualizar launcher</b>.<br/><b>2.</b> Aguarde a consulta. Se houver uma versão disponível, selecione novamente a opção.<br/><b>3.</b> O cliente recente consulta outra vez a última release antes de mostrar a confirmação.<br/><b>4.</b> Confira versão e notas. Confirme para baixar e validar.<br/><b>5.</b> O launcher fecha, o instalador substitui os arquivos do programa e o launcher reabre.')
para('Não é preciso instalar versões intermediárias. Em clientes anteriores à 0.1.4, reabrir o launcher antes da consulta evita reutilizar uma oferta antiga em memória.')
para('Para interromper uma operação, use <b>Configurações &gt; Cancelar atualização do launcher</b>. Se a conexão estiver bloqueada, a resposta pode aguardar o timeout da rede. Não desligue o computador durante a cópia de instalação.')
heading('Atualizar um jogo')
para('Selecione o jogo e abra <b>Opções do jogo &gt; Atualizar jogo</b>. Isso utiliza a fonte e as ferramentas compatíveis da biblioteca. Não é uma atualização do frontend.')
heading('Atualizar a base original')
para('Use <b>Verificar Central original</b>. Se houver mudança confirmada, a opção oficial abre o programa original para ele aplicar seu próprio update. O launcher não reescreve o código da base para fazer isso.')
note('Segurança do pacote', 'O cliente verifica o manifesto RSA-SHA256, a origem, o tamanho e o hash do instalador. Essa assinatura interna não é um certificado Authenticode de editor do Windows. Os executáveis ainda não possuem esse certificado.')

start('05. Opções e informações', 'Use apenas as funções compatíveis com cada jogo.')
heading('Ficha do jogo e versão')
para('A imagem à direita é ilustrativa e mantém sua proporção. A ficha reúne os dados disponíveis para o título. A versão instalada vem dos registros locais; ela não garante, sozinha, que a fonte remota não mudou.')
para('Número de jogadores, desenvolvedora e publisher aparecem quando houver informação local disponível. A ausência desses campos não significa que o jogo não funcione. As sinopses online foram removidas.')
heading('Adicionar um jogo extra')
para('Abra <b>Configurações &gt; Adicionar jogo</b>. Informe os campos solicitados e selecione o executável correto. O cadastro complementar fica nos dados do launcher, sem alterar o catálogo original. Use <b>Editar jogo adicional</b> para corrigir um cadastro próprio.')
para('O arquivo precisa existir e ser compatível com Windows. Cadastrar um executável não cria automaticamente uma fonte de download ou uma rotina de atualização para ele.')
heading('Renderizador')
para('A opção <b>Renderizador</b> só é útil quando o port oferece suporte identificado. Vulkan, OpenGL, Direct3D e software não são opções universais ou equivalentes. Forçar uma API incompatível pode impedir a abertura do jogo.')
note('Placa de vídeo antiga', 'Instalar o launcher, renomear uma opção ou selecionar software não garante desempenho ou compatibilidade. Não instale DLLs ou drivers desconhecidos para tentar contornar uma exigência do jogo.')
heading('Sobre e ajuda')
para('Em <b>Configurações &gt; Sobre</b>, confira versão instalada, canal, créditos e links. Essa informação é útil para relatar um problema. O avatar usa o quadro de alta resolução do ícone a partir da 0.1.3.')

start('06. Seus dados e remoção', 'Preservar jogos e saves é a escolha padrão.')
heading('Onde ficam os arquivos')
para('<b>Biblioteca:</b> jogos gerenciados por este launcher.<br/><b>Dados:</b> configurações, registros e backups de saves reconhecidos.<br/><b>Cache:</b> downloads e arquivos de trabalho.<br/><b>BackupsFrontend:</b> arquivos anteriores do programa, para recuperação.')
heading('Renomear a pasta do launcher')
para('Feche o launcher antes de renomear. Na 0.1.5, registros antigos podem ser reconectados à Biblioteca atual, com backup, se o caminho anterior não existir e o executável for encontrado. Jogos externos não são movidos. Atalhos antigos podem exigir reparo; a atualização pelo instalador os registra para a pasta atual.')
heading('Remover somente um jogo')
para('Use <b>Opções do jogo &gt; Desinstalar jogo</b>. Só instalações gerenciadas são elegíveis. A opção de guardar saves/configurações reconhecidos vem marcada. A pasta do jogo vai para a Lixeira; os backups ficam em <b>Dados/Desinstalacoes</b>. A restauração desses backups é manual.')
heading('Desinstalar o launcher')
para('Execute <b>Desinstalar</b>. Para manter os jogos, deixe <b>Remover também os jogos da Biblioteca deste launcher</b> desmarcado. Se marcar, a Biblioteca vai para a Lixeira, incluindo saves dentro das pastas dos jogos. Jogos externos e o Central original não são removidos.')
note('Não apague as pastas restantes às cegas', 'Dados, backups e jogos preservados podem continuar no disco. O desinstalador e o manifesto também podem permanecer para reinstalação. Antes de apagar qualquer pasta manualmente, confira seu conteúdo e faça backup.')

start('07. Problemas e suporte', 'Verifique a mensagem antes de repetir uma operação.')
for title, text in [
 ('Não encontrou jogos', 'Confira a raiz da biblioteca em Escolher biblioteca e recarregue o catálogo. Se a pasta do launcher foi renomeada, confira os registros gerenciados e os atalhos. Não copie o programa por cima da base original.'),
 ('Erro de status.json ou arquivo em uso', 'A correção existe desde a 0.1.2. Reabra o cliente antigo e tente atualizar. Se ele não conseguir receber a correção, baixe o setup mais recente e instale na mesma pasta do launcher, sem desinstalar.'),
 ('Falha na internet ou download incompleto', 'O pacote incompleto não deve ser instalado. Confira a conexão e tente novamente. Uma assinatura ou hash inválido bloqueia a instalação; não tente ignorar essa verificação.'),
 ('Jogo não abre / tela preta', 'Confira se o executável existe e se o port é compatível com seu hardware. A mensagem de erro pode ser do próprio jogo. O launcher não corrige automaticamente drivers ou requisitos gráficos.'),
 ('Como relatar', 'Informe a versão em Sobre, o jogo, os passos e a mensagem. Inclua uma imagem quando ajudar. Nunca publique códigos de login, senhas ou sessões do Telegram.')]:
    heading(title); para(text, gap=8)
para('<link href="https://github.com/timtompel/TarginoLauncher/issues" color="#168c34">Relatar problema no GitHub</link> | <link href="https://github.com/timtompel/TarginoLauncher/releases/latest" color="#168c34">Última versão</link> | <link href="https://t.me/TarginoLauncher" color="#168c34">Telegram do projeto</link>', kind=small)
para('Créditos de artes e fotos: consulte Recursos/Plataformas e Recursos/Controles. Os recursos conservam suas licenças próprias. Testes no mesmo Windows não substituem testes em outros computadores, controles e jogos.', kind=small)
footer(); c.save()
reader = PdfReader(str(OUT))
if len(reader.pages) != 8:
    raise RuntimeError(f'Número inesperado de páginas: {len(reader.pages)}')
if any(not p.extract_text().strip() for p in reader.pages):
    raise RuntimeError('Página sem texto')
print(f'PDF_OK={OUT} | páginas=8')
