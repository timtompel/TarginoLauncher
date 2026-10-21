"""Avisos de releases estáveis ao canal público autorizado. Não imprime segredos."""
import html
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

REPO = 'timtompel/TarginoLauncher'
CHANNEL = '@TarginoLauncher'
BASE = f'https://github.com/{REPO}'


def load_release(tag):
    if not re.fullmatch(r'v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', tag):
        raise ValueError('Informe uma tag estável vX.Y.Z.')
    request = urllib.request.Request(
        f'https://api.github.com/repos/{REPO}/releases/tags/{tag}',
        headers={'User-Agent': 'TarginoLauncher-Release-Notifier', 'Accept': 'application/vnd.github+json'},
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        if response.geturl().split('/')[2] != 'api.github.com':
            raise ValueError('Origem da release não autorizada.')
        raw = response.read(1048577)
        if len(raw) > 1048576:
            raise ValueError('Release excede o limite.')
        return json.loads(raw)


def build_message(release):
    tag = release.get('tag_name', '')
    if not re.fullmatch(r'v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', tag):
        raise ValueError('Tag inválida.')
    url = f'{BASE}/releases/tag/{tag}'
    if release.get('draft') or release.get('prerelease') or release.get('html_url') != url:
        raise ValueError('A release não é estável, pública ou do repositório esperado.')
    setup = f'TarginoLauncher-Recompilados-{tag[1:]}-Setup.exe'
    assets = release.get('assets', [])
    setup_url = f'{BASE}/releases/download/{tag}/{setup}'
    if not any(a.get('name') == setup and a.get('browser_download_url') == setup_url for a in assets):
        raise ValueError('Instalador oficial ainda não foi anexado. Nenhum aviso enviado.')
    lines = [f'🎮 <b>TarginoLauncher {html.escape(tag)}</b>', 'Nova versão estável disponível!', '']
    changes = []
    for line in str(release.get('body') or '').splitlines():
        line = line.strip()
        if line.startswith('- ') or line.startswith('* '):
            changes.append('• ' + html.escape(line[2:180].strip()))
        if len(changes) == 4:
            break
    lines.extend(changes)
    lines.extend(['', f'📥 <a href="{setup_url}">Baixar instalador completo</a>'])
    bootstrap_url = f'{BASE}/releases/download/{tag}/TarginoLauncher-Bootstrap.exe'
    if any(a.get('name') == 'TarginoLauncher-Bootstrap.exe' and a.get('browser_download_url') == bootstrap_url for a in assets):
        lines.append(f'🪶 <a href="{bootstrap_url}">Instalador leve (bootstrap)</a>')
    lines.extend([f'📋 <a href="{url}">Todas as novidades e arquivos</a>', '🌐 https://targino-programas.netlify.app/', '', 'Quem já usa: Configurações → Verificar / atualizar launcher.', 'Não inclui jogos. Base: Central Arquivista.'])
    return '\n'.join(lines)


def send_message(token, message):
    if not re.fullmatch(r'\d+:[A-Za-z0-9_-]{20,}', token):
        raise ValueError('TELEGRAM_BOT_TOKEN ausente ou inválido. Configure em GitHub Actions secrets.')
    body = json.dumps({'chat_id': CHANNEL, 'text': message, 'parse_mode': 'HTML', 'link_preview_options': {'is_disabled': True}}).encode('utf-8')
    request = urllib.request.Request(f'https://api.telegram.org/bot{token}/sendMessage', data=body, headers={'Content-Type': 'application/json'}, method='POST')
    # Sem repetição automática: uma resposta perdida não deve duplicar o aviso.
    with urllib.request.urlopen(request, timeout=20) as response:
        result = json.loads(response.read(65536))
        if result.get('ok') is not True:
            raise ValueError('Telegram não confirmou o envio. Verifique token e permissão do bot no canal.')


def main():
    token = os.environ.get('TELEGRAM_BOT_TOKEN', '').strip()
    if not token:
        raise ValueError('Configure o segredo TELEGRAM_BOT_TOKEN antes de executar. Nenhum envio realizado.')
    tag = os.environ.get('RELEASE_TAG', '').strip()
    release = load_release(tag)
    message = build_message(release)
    send_message(token, message)
    print(f'Aviso da {tag} confirmado pelo Telegram para {CHANNEL}.')


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        # Não imprima exception/URL: o endpoint do Telegram contém o token.
        print(f'Falha HTTP {error.code}. Confira a release, o segredo e a permissão de publicar no canal.', file=sys.stderr)
        sys.exit(1)
    except (ValueError, urllib.error.URLError, TimeoutError, OSError):
        print('Aviso não concluído. Confira a tag estável, o segredo TELEGRAM_BOT_TOKEN, a conexão e o acesso do bot ao canal.', file=sys.stderr)
        sys.exit(1)
