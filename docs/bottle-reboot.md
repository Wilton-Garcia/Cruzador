# Reinicialização simulada

**Reiniciar bottle** pede que você salve os arquivos, feche os programas da bottle e confirme a operação. O fluxo aguarda o servidor encerrar e então usa `wineboot --restart` no prefixo selecionado, processando as tarefas de reinicialização Wine, incluindo RunOnce. O comportamento é baseado no [wineboot do Wine 11.21](https://github.com/wine-mirror/wine/blob/wine-11.21/programs/wineboot/wineboot.c). Não é um reinício do macOS.

O Cruzador persiste o estado de preparação e o log antes de iniciar, aguarda a finalização do servidor e exige um prefixo íntegro para voltar ao estado pronto. Falha ou cancelamento não são tratados como reinicialização concluída. Programas ainda abertos mantêm a espera. Não é solicitado fechamento forçado pelo wineboot. O cancelamento pelo supervisor usa o servidor Wine exclusivamente desta bottle, como nas outras operações.

O teste nativo grava uma tarefa RunOnce com `reg.exe`, reinicia e verifica o marcador criado por essa tarefa. Os comandos e programas seguintes exercitam o mesmo prefixo. A observação não estabelece todos os cenários de encerramento de programas com documentos abertos nem equivale a reiniciar um Windows completo.
