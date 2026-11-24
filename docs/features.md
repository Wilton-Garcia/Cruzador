# Funcionalidades observadas do CrossOver

O catálogo reúne 17 superfícies observadas pela acessibilidade do aplicativo, com 114 itens, e 216 declarações de ações dos arquivos compilados de interface. Um item pode aparecer em mais de uma superfície; o número de controles não é o número de funcionalidades distintas.

A navegação confirmou biblioteca, catálogo de instalação, instalação não listada, criação de bottles, seleção de templates, execução com ambiente e logs, ações de manutenção, backends gráficos e preferências de integração. O menu Garrafa também declara duplicação, renomeação, importação, exportação, publicação, encerramento e shell. As operações não foram executadas só por aparecerem no catálogo.

A instalação Steam que já estava em andamento foi cancelada após autorização explícita do usuário. A interface confirmou o cancelamento e continuou exibindo a bottle como pronta. Isso não demonstra uma instalação completa ou uma reversão dos arquivos já criados. As outras ações dessa observação foram apenas navegação e abertura/fechamento de diálogos, sem alterar opções.

O registro diferencia evidência de interface em execução de declarações de arquivos NIB. Uma declaração estática não prova que o controle esteja habilitado ou acessível em execução. Há elementos dinâmicos e estados dependentes de programas instalados que ainda podem ampliar o catálogo.

- [Observações de acessibilidade](../evidence/ui-observations.json): transcrição dos controles e estados observados.
- [Declarações de interface](../evidence/interface-declarations.json): nós e proveniência REA dos seletores.
- [Catálogo projetado](../evidence/feature-catalog.json): identificadores estáveis por observação/declaração.

Verificação: `python3 scripts/build-feature-catalog.py --check`. O comando verifica a projeção determinística, não reexecuta o aplicativo nem comprova o resultado das operações.
