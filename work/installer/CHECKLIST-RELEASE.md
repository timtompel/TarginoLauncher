# Checklist obrigatorio de publicacao

Uma release nao esta concluida enquanto os tres destinos nao estiverem conferidos:

1. GitHub: Setup, Bootstrap e update.json assinados/validados, fontes, tag estavel correta e Latest.
2. Site https://targino-programas.netlify.app/: baixar pelo URL permanente https://github.com/timtompel/TarginoLauncher/releases/latest/download/TarginoLauncher-Bootstrap.exe . Conferir redirecionamento para a release nova; atualizar notas/fallback de versao do HTML ao publicar mudancas no site. Nao fixar o botao em uma tag antiga. Se uma nova release nao tiver bootstrap, nao publica-la como Latest antes de anexar o arquivo.
3. Telegram @TarginoLauncher: conferir sucesso do workflow telegram-release.yml no evento published. Confirmar aviso com links oficiais, sem reenviar manualmente se ja houver sucesso.

O site esta hospedado no Netlify existente, por upload manual. O download permanente acompanha Latest sem redeploy, inclusive sem JavaScript/API. O rotulo de versao consulta a API publica; na indisponibilidade pode mostrar a versao de referencia do ultimo deploy, mas o botao continua buscando Latest.
Nao apagar ou sobrescrever assets de releases anteriores. Nunca publicar tokens, sessoes ou jogos.

