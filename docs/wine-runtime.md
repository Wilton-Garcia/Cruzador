# Motor Wine do Cruzador

O Cruzador aceita um pacote Wine próprio, selecionado como **Pacote Wine do Cruzador**, além dos modos externos usados na investigação. Essa integração não depende de caminhos da instalação do CrossOver e não faz fallback para ela quando o pacote está ausente ou inválido.

A base escolhida para o motor de compatibilidade é Wine aberto. A camada de interface, gerenciamento, execução e recuperação do Cruzador é própria. A investigação do CrossOver fornece evidência de comportamento; seus executáveis, módulos de negócio e componentes proprietários não foram copiados para a distribuição do aplicativo.

O código upstream descreve Wine como software livre sob LGPL e mantém instruções de compilação no [README do projeto](https://github.com/wine-mirror/wine/blob/master/README.md). A [página de fontes da CodeWeavers](https://www.codeweavers.com/crossover/source) distingue os projetos FOSS usados no CrossOver e aponta seus upstreams. A distribuição macOS também possui [receitas e pacotes do mantenedor](https://github.com/Gcenx/macOS_Wine_builds). Essas referências não demonstram que uma compilação específica seja equivalente ao motor examinado.

## Formato admitido

O pacote é uma pasta com `runtime.json`, executáveis Wine e wineserver e os textos de licença indicados. O manifesto tem formato 1, identificador `org.winehq.wine`, versão, URL/revisão de origem, arquiteturas declaradas e caminhos relativos. Sua interpretação pertence a `WineRuntime`; consumidores usam os caminhos já resolvidos por esse objeto.

O manifesto identifica `wineExecutable`, `serverExecutable` e `licenseFiles`. Componentes externos à raiz do pacote, inclusive por symlinks, são recusados. Um pacote sem componente ou proveniência obrigatória gera erro específico. A declaração de arquitetura não substitui a inspeção real dos binários.

No lançamento, o adaptador usa o Wine do pacote, o wineserver do mesmo pacote e o prefixo escolhido para a bottle. Não injeta `CX_BOTTLE` ou usa ferramentas da instalação do CrossOver. O ambiente herdado continua pertencendo ao processo; somente as substituições explicitamente escolhidas compõem o comando do adaptador.

O caminho padrão de um pacote incluído no aplicativo é `Contents/Resources/Runtime`. A interface permite selecionar uma pasta com manifesto ou esse caminho padrão. O build pode incluir um pacote Wine real preparado pelo procedimento abaixo; a presença do pacote não estabelece compatibilidade com todos os programas Windows.

## Validação

Os testes executam uma ferramenta de fixture dentro de um pacote temporário e verificam seleção do servidor/prefixo, ausência de fallback, componentes ausentes e resolução fora da raiz. Eles não estabelecem compatibilidade Wine nem uma distribuição independente pronta. A preparação de um pacote real e a validação de suas dependências são etapas separadas.

## Preparação reproduzível do pacote real

`config/wine-runtime-lock.json` fixa Wine 11.21, o asset macOS do mantenedor, sua URL e SHA-256, além dos textos de licença upstream selecionados. `python3 scripts/prepare-wine-runtime.py` verifica os downloads, valida os caminhos do arquivo tar e prepara `.local/Runtime-11.21`. A extração não instala software no sistema e não usa binários do CrossOver.

O pacote tem inventário por arquivo e link, com hashes dos arquivos regulares. Repetir a preparação verifica e reutiliza um pacote idêntico; metadados ou licenças diferentes não são aceitos silenciosamente. O build inclui esse runtime quando presente, ou usa a pasta explicitamente selecionada por `CRUZADOR_RUNTIME_PATH`. A cópia para o app é verificada e uma versão substituída é preservada como backup. Pacotes e downloads ficam fora do Git.

O pacote real foi incluído no Cruzador.app local; a verificação do inventário passou após a cópia e a assinatura ad hoc do aplicativo foi conferida. O executável incluído retornou `wine-11.21` com status 0. O [registro de preparação](../evidence/runtime-package.json) preserva a identidade e os limites dessa validação.

É um pacote de desenvolvimento: os textos de licença Wine selecionados estão incluídos, mas a revisão integral das atribuições e correspondência de fontes de todas as dependências do pacote do mantenedor ainda não foi concluída. Nenhuma declaração de conformidade integral para redistribuição pública é feita. A inspeção de arquiteturas e os cenários Windows do motor próprio são validações separadas do preparo do pacote.

## Execução e arquiteturas

`swift test --jobs 4` executa os testes locais; o cenário Wine real é opt-in. Após compilar os testes, execute `python3 scripts/native-smoke.py --runtime .local/Runtime-11.21`. O supervisor cria uma pasta nova, limita a duração do teste e preserva os logs. O cenário cria um prefixo, executa os `cmd.exe` de 64 e 32 bits, verifica seus cabeçalhos PE, observa um marcador de saída, verifica a propagação do código 7 e aguarda o servidor. O relatório fica em `.local/packaged-runtime-smoke.json`.

A inicialização inclui `wineserver -w` como fase de finalização. O término de `wineboot` sozinho não garante que o registro tenha sido gravado; a prontidão só é avaliada após essa fase. Uma falha na finalização permanece falha da operação.

`CRUZADOR_UNIVERSAL=1 scripts/build-app.sh` compila o aplicativo para arm64 e x86_64. `python3 scripts/verify-architectures.py` verifica as imagens com `lipo` e registra também a versão mínima indicada por `vtool`. O aplicativo é universal; o pacote Wine fixado contém executáveis x86_64, que exigem Rosetta em Apple Silicon. A verificação de slices não comprova execução em ambas as máquinas. O workflow `Runtime architectures` separa os cenários reais em runners Apple Silicon e Intel, preservando seus relatórios; qualquer resultado deve ser associado ao commit e à execução correspondentes.

A [execução registrada](../evidence/runtime-architecture-ci.json) passou em ambos os runners, incluindo programas Windows de 32/64 bits e build universal. O registro identifica o commit exercitado e preserva os relatórios de cada arquitetura.

Novas configurações selecionam o pacote incluído. Preferências externas já salvas e o motor de cada bottle existente são preservados; preferências incompletas exigem uma seleção explícita. O build do aplicativo recusa um pacote ausente e indica como prepará-lo.
