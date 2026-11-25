# Integração com macOS

O aplicativo declara abertura de EXE/MSI como alternativa em **Abrir com**, sem alterar o aplicativo padrão dessas extensões. Também registra arquivos `.cruzadorapp`, pastas `.cruzadorbottle` e o esquema de URL `cruzador`. O registro passa a existir quando o macOS reconhece o aplicativo compilado; não há alteração manual do banco Launch Services pelo instalador.

**Arquivo → Abrir…** e **Abrir recentes** passam pelo mesmo contrato de abertura usado nos eventos do Finder. O delegado AppKit possui a janela principal e os eventos externos, cria a janela no primeiro pedido e volta a exibi-la ao reabrir o aplicativo. A interface dessa janela é SwiftUI. Uma tela mostra a origem e a ação antes de iniciar qualquer programa ou importação. EXE/MSI permitem escolher uma bottle pronta e executar ou abrir o assistente de instalação. Transferências usam o motor selecionado nas configurações, preservam a origem e geram uma cópia com novos identificadores. Os arquivos só entram em recentes quando a ação é aceita; essa lista é gerida pelo macOS e pode ser limpa no menu.

Se vários pedidos chegarem, o Cruzador mantém os demais no botão **Arquivos recebidos**. Eles exigem revisão individual e aguardam operações em andamento. Fechar a tela não executa os próximos pedidos automaticamente.

No menu de contexto de um aplicativo da biblioteca, **Exportar atalho para o Finder…** cria um `.cruzadorapp`. Ele contém somente a versão do formato e os UUIDs da bottle e do aplicativo. O programa e seus argumentos são lidos da biblioteca atual quando o atalho é aberto. Mover o arquivo não rompe a referência; remover ou duplicar/importar a bottle não redireciona o atalho antigo para outra instalação. Exporte outro arquivo nesse caso. O formato não é um bundle `.app`, não carrega ícones do original e não inclui Wine.

**Copiar link do atalho** gera `cruzador://launch/<bottle-UUID>/<app-UUID>`. O link também abre a revisão. Parâmetros, fragmentos, credenciais, portas e formatos desconhecidos são recusados. Arquivos e URLs não fornecem um campo de comando arbitrário. A seleção do motor, prontidão e validação do executável continuam pertencendo à biblioteca e ao fluxo de execução.

A integração atual não associa documentos Windows arbitrários aos programas instalados, não abre arquivos `.lnk` e não estabelece equivalência com serviços, Dock, ícones ou launchers do CrossOver. A validação dos contratos usa `ExternalOpeningTests`; a validação de empacotamento e a observação da interface têm escopos separados.

A [observação nativa registrada](../evidence/runtime-macos-integration.json) recebeu o arquivo na abertura inicial e um link com o aplicativo já aberto: os pedidos ficaram na fila de revisão, e o aplicativo informou sua janela visível. A ferramenta de inspeção visual não conseguiu obter a janela (`cgWindowNotFound`); portanto, essa observação não comprova layout, clique duplo no Finder ou interação com os menus.
