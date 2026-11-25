# Cobertura de reconstrução

Matriz de evidência, implementação e validação do protótipo atual. `partial` significa implementação parcial no código, normalmente dependente de motor externo. `missing` indica ausência de implementação mapeada. Nenhum grupo tem equivalência independente estabelecida.

Há 40 grupos revisados e 330 itens de catálogo. 107 itens têm vínculo com um grupo; os outros 223 permanecem explicitamente não avaliados. Controles repetidos e ações de framework não são funcionalidades independentes.

| Capacidade | Conhecimento do original | Protótipo | Validação referenciada | Diferença restante |
| --- | --- | --- | --- | --- |
| Biblioteca e atalhos | ui-observation | partial | Motor real; execução de cmd.exe, sem descoberta automática de apps | Biblioteca própria existe; descoberta automática e equivalência com launchers do original não implementadas. |
| Catálogo e busca de instaladores | ui-observation | missing | Sem teste específico referenciado | Sem catálogo de receitas próprio. |
| Compatibilidade e avaliações | ui-observation | missing | Sem teste específico referenciado | Sem matriz de compatibilidade publicada e sem envio de avaliações. |
| Instalação EXE/MSI e programas não listados | ui-observation | partial | Montagem de argv com motor simulado | Instalador genérico encaminhado ao motor externo; instalação real e recuperação ainda não validadas. |
| Progresso e cancelamento da instalação | runtime-observed-cancellation | missing | Sem teste específico referenciado | Cancelamento foi observado no original; o Cruzador ainda não cancela subprocessos. |
| Origem local e download de instaladores | ui-observation | partial | Sem teste específico referenciado | Seleção local existe no protótipo; downloads geridos e verificação não reconstruídos. |
| Receitas e dependências | python-metadata | missing | Sem teste específico referenciado | Metadados InstallTask examinados; instruções e semântica de resolução pendentes. |
| Criação de bottles | native-decompilation | partial | Criação real via CrossOver instalado | Criação encaminhada ao CrossOver/Wine externo; não há motor distribuído próprio. |
| Templates e versões Windows | native-and-python-metadata | partial | Sem teste específico referenciado | Protótipo CrossOver fixa win10_64; seleção de outros templates e arquiteturas ausente. |
| Duplicação de bottles | native-decompilation | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Renomeação de bottles | native-and-python-metadata | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Remoção de bottles | python-metadata | missing | Sem teste específico referenciado | Sem remoção de bottles no Cruzador; preservar estado ativo e recuperação. |
| Exportação de bottles | python-metadata | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Importação de bottles | native-and-python-metadata | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Publicação e bottles gerenciadas | python-metadata | missing | Sem teste específico referenciado | Controles vistos; atualização estava desabilitada. Sem implementação própria. |
| Bottle padrão | python-metadata | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Local de armazenamento e integração de launchers | ui-observation | partial | Armazenamento próprio e backup de metadados | Armazenamento próprio fixo; mudança de local, migração e exportação de launchers não implementadas. |
| Abrir unidade C: | ui-observation | partial | Sem teste específico referenciado | Abre a pasta do prefixo inteiro; abertura direta de drive_c e integração completa pendentes. |
| Execução de comandos e atalhos | native-decompilation | partial | cmd.exe no motor CrossOver real; Isolamento de prefixo e argumentos; Execução de fixture em pacote próprio; não é teste de compatibilidade Wine | Executa EXE/MSI com argumentos por linha; não reproduz o parser livre e todos os modos de launcher. |
| Ambiente e presets de execução | native-decompilation | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Logs, canais e erros de execução | native-decompilation | partial | Saída em arquivo e status não zero | Logs simples existem; seleção de canais, ambiente e relatório detalhado faltam. |
| Shell da bottle | native-decompilation | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Encerramento e saída forçada | python-metadata | missing | Sem teste específico referenciado | Sem supervisão/cancelamento completo no produto; smoke test apenas aguarda wineserver próprio. |
| Reinicialização simulada | python-metadata | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Reparo de bottles e menus | archive-and-ui-declaration | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Backends gráficos | native-and-python-metadata | missing | Sem teste específico referenciado | Seletores e chaves identificados; renderizadores e disponibilidade não reconstruídos. |
| DLSS | python-metadata | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| MSync e reinício necessário | native-and-python-metadata | missing | Sem teste específico referenciado | Confirmação e metadados conhecidos; implementação e ciclo de reinício não reconstruídos. |
| Alta resolução | python-metadata | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Configuração Wine e registro | ui-observation | partial | Sem teste específico referenciado | Botões encaminham ferramentas externas; ferramentas reais não foram exercitadas. |
| Controles de jogos | ui-observation | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Gerenciador de tarefas Windows | ui-observation | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Configurações de Internet | ui-observation | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Detalhes da bottle | python-metadata | partial | Preserva metadados inválidos | Três estados próprios; estados e capacidades detalhadas do original não reproduzidos. |
| Abrir arquivos e recentes | ui-observation | missing | Sem teste específico referenciado | Sem associação de arquivos e documentos recentes do Cruzador. |
| Preferências de instalação e cache | ui-observation | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Atualização do aplicativo | ui-observation | missing | Sem teste específico referenciado | Comportamento ainda não reconstruído. |
| Preferências e ciclo do aplicativo | ui-observation | partial | Sem teste específico referenciado | Configuração básica de motor e bloqueio de saída durante operação; restauração de janelas e demais preferências ausentes. |
| Sobre e serviços macOS | ui-observation | missing | Sem teste específico referenciado | Itens padrão de macOS não estabelecem paridade de produto. |
| Ativação da edição original | ui-observation | missing | Sem teste específico referenciado | Observado apenas como controle; nenhuma ativação ou alteração de licença foi executada. Modelo de distribuição próprio ainda não definido. |

Os testes referenciados são os já existentes. A execução nativa registrada cobriu criação e `cmd.exe` via CrossOver instalado, não independência, instalação arbitrária ou todos os controles do Wine. A captura de interface do original comprova presença e estados observados, não sucesso de todas as operações.

[Avaliações revisadas](../evidence/capability-assessments.json) · [Matriz estruturada](../evidence/coverage-matrix.json).

Verifique a projeção com `python3 scripts/build-coverage-matrix.py --check`. Alterações nos arquivos referenciados mudam os hashes; a avaliação semântica deve ser revista quando o comportamento mudar.
