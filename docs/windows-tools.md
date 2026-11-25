# Ferramentas Windows da bottle

As ferramentas usam o mesmo planejador, ambiente e supervisor dos programas Windows. Identidades tipadas evitam nomes livres de ferramentas. O painel de controles exige `control.exe` e `joy.cpl` íntegros como arquivos PE de arquitetura compatível na pasta System32 da bottle selecionada; componentes ausentes ou malformados produzem uma mensagem para preparar/reparar essa bottle.

**Controles de jogos** abre o painel `joy.cpl` do Wine. O [painel do Wine 11.21](https://github.com/wine-mirror/wine/blob/wine-11.21/dlls/joy.cpl/joy.rc) oferece listagem, habilitação, testes de eixos/botões e abas das interfaces que o motor suporta. A presença dessas funções não comprova suporte a todos os dispositivos, mapeamentos, vibração ou drivers do macOS.

Enquanto uma ferramenta estiver aberta, ela pode manter a operação em andamento. Feche sua janela para continuar ou use Cancelar operação, que encerra os programas Wine **desta bottle** pelo servidor selecionado. Não há encerramento global de outros prefixos.

O [registro de inspeção](../evidence/runtime-gamepad-panel.json) distingue plano produzido pelo código, processo observado e limites. A ferramenta nativa de UI não conseguiu acessar o processo Windows sem bundle macOS; não se apresenta atividade do processo como prova de conteúdo da janela. Não houve teste com controle físico.
