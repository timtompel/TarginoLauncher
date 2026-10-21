# Avisos automáticos no Telegram

Destino autorizado: canal público @TarginoLauncher, https://t.me/TarginoLauncher.

1. Crie o bot pelo @BotFather. Se algum token apareceu em mensagem/imagem, revogue-o antes de usar.
2. Adicione @TarginoLauncherAvisosBot ao canal como administrador, com permissão de publicar mensagens. Não são necessárias permissões de excluir mensagens ou adicionar administradores.
3. No repositório timtompel/TarginoLauncher: Settings > Secrets and variables > Actions > New repository secret.
4. Nome exato: TELEGRAM_BOT_TOKEN. Cole o token atual somente no campo secreto do GitHub.
5. Publique uma release estável com o Setup e update.json já anexados. O workflow Avisar release no Telegram roda no evento published. Não roda em pushes comuns, rascunhos ou prévias.

Para testar depois de configurar: Actions > Avisar release no Telegram > Run workflow, informe v0.1.9. Isso envia uma mensagem real ao canal. Repetir manualmente ou usar Re-run pode duplicar o anúncio; não há banco persistente de avisos.

O token não fica no código. O script não imprime token, URL de API que o contém nem corpo de erro do Telegram. Não habilita broadcasts pagos. Usa somente um envio comum por publicação, sem servidor próprio e sem computador ligado.

Os serviços podem mudar seus planos. Referências: https://core.telegram.org/bots e https://docs.github.com/en/actions/concepts/billing-and-usage . GitHub Actions em runners padrão é gratuito para repositórios públicos conforme a documentação consultada.
