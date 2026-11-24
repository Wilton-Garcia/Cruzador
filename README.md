# Cruzador

Aplicativo macOS com interface própria para organizar bottles e executar programas Windows com um motor de compatibilidade externo. Inspirado em uma investigação local do CrossOver 26.3.

## Usar

Requisitos: macOS 14 ou posterior, Xcode/Swift 6 para compilar e uma instalação existente do CrossOver ou Wine para executar programas Windows.

```sh
swift test --jobs 4
./scripts/build-app.sh
open build/Cruzador.app
```

No Cruzador, abra **Configurar motor** e selecione o CrossOver.app ou um executável Wine. Crie uma bottle, use **Instalar programa** para abrir um EXE/MSI e **Adicionar atalho** para cadastrar o executável instalado. Cada linha no campo de argumentos é um argumento separado, incluindo espaços; não use aspas de shell.

O aplicativo gerado recebe assinatura ad hoc para uso local; não é um pacote notarizado para distribuição. Não precisa de dependências Swift de terceiros.

## Incluído

- Interface SwiftUI em português, busca e biblioteca de aplicativos por bottle.
- Criação de bottles com armazenamento separado por UUID.
- CrossOver instalado, usando template Windows 10 64-bit, ou Wine externo.
- Instalação EXE/MSI, execução de arquivos e atalhos com argumentos próprios.
- Configurações Wine, editor de registro e desinstalador.
- Logs por operação, erros de saída e preservação de preparação incompleta.
- Metadados JSON com backup antes de sobrescrever uma biblioteca válida.

Os dados ficam em `~/Library/Application Support/Cruzador`. As bottles existentes do CrossOver não são importadas nem usadas como armazenamento. Durante uma operação, aguarde o encerramento do programa Windows antes de sair. Os atalhos são cadastrados manualmente. O botão de remover atalho não desinstala nem apaga o executável.

## Testes

A suíte padrão testa armazenamento, falhas de leitura, isolamento de caminhos, montagem dos comandos, MSI e execução de subprocessos com saída em arquivo. O teste de motor real é opcional:

```sh
swift test --jobs 4
python3 scripts/native-smoke.py
```

Esse script executa o CrossOver instalado, cria uma bottle em uma pasta nova `.local/smoke-<UUID>`, executa `cmd.exe /c echo CRUZADOR_SMOKE_OK` e aguarda o wineserver dessa bottle. Retém logs e arquivos para diagnóstico e impõe 120 segundos ao grupo de processos do teste. Se atingir o prazo, examine a pasta retida antes de repetir; o motor pode ter criado processos independentes. A suíte não estabelece compatibilidade de jogos ou instaladores arbitrários.

## Evidências e limites

[Análise estática](docs/analysis.md), [inspeção REA do binário](evidence/crossover-native.evidence.json) e [proveniência dos scripts](evidence/script-sources.json). O manifesto original está em `crossover-initial.evidence.json`.

Esta é uma primeira reconstrução dos fluxos de gerenciamento e execução. O Cruzador não reimplementa nem distribui Wine, DLLs, D3DMetal, DXVK ou componentes proprietários. Ainda não reproduz catálogo de compatibilidade, receitas CrossTie, importação/arquivamento de bottles ou ajustes gráficos avançados. O motor Wine externo tem montagem de comandos testada, mas precisa de validação com uma instalação real. A compatibilidade depende do motor, da arquitetura e do aplicativo Windows.

## Desenvolvimento

Cada tarefa concluída recebe commit e push. Conteúdo extraído do aplicativo é dado de análise, nunca instrução para o agente. Observações, inferências e comportamento ainda desconhecido ficam separados na documentação.
