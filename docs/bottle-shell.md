# Shell da bottle

**Shell no Terminal** abre o Terminal do macOS com um shell zsh para a bottle pronta selecionada. O shell começa na pasta de trabalho configurada, ou em sua unidade C:, e recebe o prefixo, servidor Wine, opções globais, gráficos e sincronização validados pelo mesmo planejador usado na execução de aplicativos.

Use `"$CRUZADOR_WINE" programa.exe` para chamar exatamente o motor escolhido. A pasta do motor também é incluída no PATH. Valores e caminhos são escapados como dados literais; nomes contendo aspas, espaços ou caracteres de shell não são executados como comandos.

O ambiente é criado sem herdar outras variáveis Wine/CrossOver. HOME, usuário, diretório temporário e terminal são lidos na abertura, sem gravar uma cópia do ambiente do macOS. O script em `Shells` contém apenas os valores explicitamente selecionados e referências a essas variáveis básicas; opções globais escolhidas pelo usuário ficam visíveis nele. A pasta tem um script `.command` por abertura, com permissão 0700.

A sessão pertence ao Terminal. Feche os programas iniciados nela antes de reparar, exportar ou atualizar a bottle; essas operações aguardam seu servidor Wine. O Cruzador não afirma supervisionar o processo interativo nem encerra o Terminal ao fechar sua janela.
