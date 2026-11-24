# CrossOver 26.3: observações para o Cruzador

A análise estática cobre o manifesto, a estrutura Mach-O arm64 e quatro scripts/módulos distribuídos no aplicativo. Não houve execução do CrossOver nesta etapa.

## Arquitetura observada

A evidência REA `ev_2bcd2bd74a9ebae8c6ff47d11b89627b593094784203fe3c6ee9b8b07e069dc9` registra duas arquiteturas e 23 dependências declaradas. A página `ev_a122b1ff84f09ab8bbee56577369de2e096c129d7e2c9d40c53fcf160a311700` inclui AppKit, Cocoa, Python 3.13 e Sparkle. Isso estabelece dependências, não o papel preciso de cada uma em execução. O bundle completo está em `evidence/crossover-native.evidence.json`.

Os scripts públicos locais, identificados por caminho e digest em `evidence/script-sources.json`, expõem:

- `cxbottle`: criação com nome, template e escopo, além de cópia e arquivamento.
- `cxstart`: seleção de bottle, diretório de trabalho e política de espera; inicia o comando com argumentos separados.
- `CXBottle.pm`: localização privada/gerenciada, descoberta usando `system.reg` e validação de acesso separada da localização.
- `wine`: configuração do ambiente de uma bottle antes da execução.

Os templates instalados incluem `win10_64` e `win11_64`. A presença de MoltenVK e de diretórios gráficos é observada; o fluxo gráfico não foi rastreado.

## Decisões do Cruzador

Interface própria em SwiftUI, biblioteca de bottles com identificadores UUID, metadados JSON e diretórios independentes. Um adaptador usa o CrossOver instalado por caminho explícito; outro usa Wine externo. O Cruzador não distribui nem reimplementa o motor Wine, DLLs ou componentes gráficos do CrossOver. Não usa as bottles existentes do CrossOver como armazenamento próprio.

A primeira versão cobre criação de bottles, biblioteca de executáveis, execução, instaladores EXE/MSI, ferramentas Wine e logs por operação. Catálogo de compatibilidade, receitas CrossTie, migração de bottles, recursos gráficos avançados e equivalência completa continuam sem implementação. Compatibilidade real depende do motor e de cada aplicativo; testes com um motor simulado não provam compatibilidade Windows.
