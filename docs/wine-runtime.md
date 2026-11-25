# Motor Wine do Cruzador

O Cruzador aceita um pacote Wine próprio, selecionado como **Pacote Wine do Cruzador**, além dos modos externos usados na investigação. Essa integração não depende de caminhos da instalação do CrossOver e não faz fallback para ela quando o pacote está ausente ou inválido.

A base escolhida para o motor de compatibilidade é Wine aberto. A camada de interface, gerenciamento, execução e recuperação do Cruzador é própria. A investigação do CrossOver fornece evidência de comportamento; seus executáveis, módulos de negócio e componentes proprietários não foram copiados para a distribuição do aplicativo.

O código upstream descreve Wine como software livre sob LGPL e mantém instruções de compilação no [README do projeto](https://github.com/wine-mirror/wine/blob/master/README.md). A [página de fontes da CodeWeavers](https://www.codeweavers.com/crossover/source) distingue os projetos FOSS usados no CrossOver e aponta seus upstreams. A distribuição macOS também possui [receitas e pacotes do mantenedor](https://github.com/Gcenx/macOS_Wine_builds). Essas referências não demonstram que uma compilação específica seja equivalente ao motor examinado.

## Formato admitido

O pacote é uma pasta com `runtime.json`, executáveis Wine e wineserver e os textos de licença indicados. O manifesto tem formato 1, identificador `org.winehq.wine`, versão, URL/revisão de origem, arquiteturas declaradas e caminhos relativos. Sua interpretação pertence a `WineRuntime`; consumidores usam os caminhos já resolvidos por esse objeto.

O manifesto identifica `wineExecutable`, `serverExecutable` e `licenseFiles`. Componentes externos à raiz do pacote, inclusive por symlinks, são recusados. Um pacote sem componente ou proveniência obrigatória gera erro específico. A declaração de arquitetura não substitui a inspeção real dos binários.

No lançamento, o adaptador usa o Wine do pacote, o wineserver do mesmo pacote e o prefixo escolhido para a bottle. Não injeta `CX_BOTTLE` ou usa ferramentas da instalação do CrossOver. O ambiente herdado continua pertencendo ao processo; somente as substituições explicitamente escolhidas compõem o comando do adaptador.

O caminho padrão de um pacote incluído no aplicativo é `Contents/Resources/Runtime`. A interface permite selecionar uma pasta com manifesto ou esse caminho padrão. Nesta etapa, o formato e a integração estão implementados; ainda não há um pacote Wine real distribuído pelo build do Cruzador.

## Validação

Os testes executam uma ferramenta de fixture dentro de um pacote temporário e verificam seleção do servidor/prefixo, ausência de fallback, componentes ausentes e resolução fora da raiz. Eles não estabelecem compatibilidade Wine nem uma distribuição independente pronta. A preparação de um pacote real e a validação de suas dependências são etapas separadas.
