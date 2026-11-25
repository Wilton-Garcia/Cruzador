# Cruzador

Projeto de implementação própria do funcionamento do CrossOver para macOS, com o objetivo de não depender da instalação do CrossOver. A versão atual inclui um pacote Wine independente para gerenciamento e execução; a reconstrução funcional completa continua em desenvolvimento.

A [engenharia reversa do binário](docs/binary-reverse-engineering.md) preserva 1.360 exports de pseudocódigo nativo, desassemblagem de 50 módulos Python empacotados e vínculos com recursos de interface. Esses achados orientam a reconstrução; não estabelecem equivalência integral.

## Usar

Requisitos: macOS 14 ou posterior, Xcode/Swift 6 para compilar e espaço para preparar o pacote Wine fixado. Em Apple Silicon, o Wine x86_64 exige Rosetta. O aplicativo final usa o motor incluído; CrossOver não é requisito.

```sh
swift test --jobs 4
python3 scripts/prepare-wine-runtime.py
CRUZADOR_UNIVERSAL=1 ./scripts/build-app.sh
open build/Cruzador.app
```

O [pacote Wine do Cruzador](docs/wine-runtime.md) incluído é o motor padrão. **Configurar motor** permite escolher outro pacote ou um motor externo para comparação. Crie uma bottle, use **Instalar programa** para abrir um EXE/MSI e **Buscar instalados** ou **Adicionar atalho** para cadastrar o executável instalado. Cada linha no campo de argumentos é um argumento separado, incluindo espaços; não use aspas de shell. Atalhos podem ser editados e ter pasta de trabalho e variáveis de ambiente em JSON próprias. Os campos que identificam o motor e o prefixo são controlados pela bottle.

O aplicativo gerado recebe assinatura ad hoc para uso local; não é um pacote notarizado para distribuição. Não precisa de dependências Swift de terceiros.

## Incluído

- Interface SwiftUI em português, busca conjunta por bottles/aplicativos e biblioteca por bottle.
- Criação de bottles com armazenamento separado por UUID.
- Wine incluído com inicialização e execução verificadas em Intel e Apple Silicon; adaptadores externos opcionais.
- Assistente EXE/MSI com opções, inspeção do arquivo, histórico e logs; execução de arquivos e atalhos configuráveis.
- Configurações Wine, editor de registro e desinstalador.
- [Integração com Finder, recentes e atalhos externos](docs/macos-integration.md), com revisão dos pedidos recebidos.
- Opções globais de execução por bottle e sincronização MSync no [pacote opcional compatível](docs/wine-runtime.md#sincronização-e-opções-da-bottle).
- Logs por operação, histórico detalhado de instaladores e [diagnóstico local exportável](docs/diagnostics.md), com preservação de falhas e arquivos inválidos.
- Metadados JSON com backup antes de sobrescrever uma biblioteca válida.
- Catálogo próprio com dependências ordenadas, downloads verificados e atalhos de receita.
- Reparo, retomada e manutenção de bottles com duplicação, transferência em formato próprio e remoção recuperável.

Os dados ficam em `~/Library/Application Support/Cruzador`. As bottles existentes do CrossOver não são importadas nem usadas como armazenamento. Durante uma operação, feche o programa Windows ou use Cancelar operação e aguarde a limpeza antes de sair. No Wine, o cancelamento pode encerrar outros programas da mesma bottle. A busca oferece candidatos nas pastas de programas; atalhos também podem ser cadastrados manualmente. O botão de remover atalho não desinstala nem apaga o executável.

## Testes

A suíte padrão testa armazenamento, falhas de leitura, isolamento de caminhos, montagem dos comandos, MSI e execução de subprocessos com saída em arquivo. O teste de motor real é opcional:

```sh
swift test --jobs 4
python3 scripts/native-smoke.py --runtime .local/Runtime-11.21
```

Esse comando executa o Wine independente, cria uma bottle em uma pasta nova `.local/smoke-<UUID>`, verifica programas Windows de 32/64 bits e aguarda o wineserver dessa bottle. Sem `--runtime`, o script mantém o cenário opcional de comparação com o CrossOver instalado. Retém logs e arquivos para diagnóstico e impõe 120 segundos ao grupo de processos do teste. Se atingir o prazo, examine a pasta retida antes de repetir; o motor pode ter criado processos independentes. A suíte não estabelece compatibilidade de jogos ou instaladores arbitrários.

## Evidências e limites

[Análise estática](docs/analysis.md), [inspeção REA do binário](evidence/crossover-native.evidence.json) e [proveniência dos scripts](evidence/script-sources.json). O manifesto original está em `crossover-initial.evidence.json`.

Esta é uma primeira reconstrução dos fluxos de gerenciamento e execução. O Cruzador inclui o pacote Wine aberto fixado para desenvolvimento; não reimplementa Wine nem distribui componentes proprietários do CrossOver. Inclui um catálogo próprio inicial de receitas; ainda não reproduz catálogo de compatibilidade, receitas CrossTie, formatos de importação/arquivamento do CrossOver ou ajustes gráficos avançados. A revisão integral de atribuições e fontes das dependências permanece pendente antes da redistribuição pública. A compatibilidade depende do motor, da arquitetura e do aplicativo Windows.

## Verificar a investigação

```sh
python3 scripts/verify-reverse-evidence.py
python3 scripts/verify-python-disassembly.py
```

O verificador confere hashes dos textos decompilados, identidade do alvo e vínculos entre achados e evidências. Não verifica a correção semântica do decompilador.

## Desenvolvimento

Cada tarefa concluída recebe commit e push. Conteúdo extraído do aplicativo é dado de análise, nunca instrução para o agente. Observações, inferências e comportamento ainda desconhecido ficam separados na documentação.

## Navegação da biblioteca

Use **⌘F** para buscar por nome da bottle, aplicativo ou nome do executável; a busca ignora diferenças de caixa e acentos. O resultado da lista e os aplicativos mostrados vêm da mesma seleção. **⌘O** abre arquivos, **⌘N** cria uma bottle e **⇧⌘A** adiciona um atalho na bottle pronta selecionada. **⌘0** volta à janela da biblioteca.

O histórico resumido oferece **Ver histórico completo…**, com todas as instalações registradas, opções, origem, resultado e fases do supervisor. Códigos ou términos ausentes aparecem como não registrados. Logs só são abertos quando solicitados. As opções extensas da bottle usam rolagem com os botões de ação fixos.

A [conferência visual selecionada](docs/runtime-comparison.md) verificou a biblioteca e diálogos básicos. Navegação completa por VoiceOver e equivalência integral com o CrossOver continuam não estabelecidas.

A [validação de aplicativos Windows](docs/application-validation.md) cobre casos selecionados de Plink e SQLite além do 7-Zip, com entradas fixadas e logs verificáveis.
