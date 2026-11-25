# Motor Wine do Cruzador

O Cruzador aceita um pacote Wine próprio, selecionado como **Pacote Wine do Cruzador**, além dos modos externos usados na investigação. Essa integração não depende de caminhos da instalação do CrossOver e não faz fallback para ela quando o pacote está ausente ou inválido.

A base escolhida para o motor de compatibilidade é Wine aberto. A camada de interface, gerenciamento, execução e recuperação do Cruzador é própria. A investigação do CrossOver fornece evidência de comportamento; seus executáveis, módulos de negócio e componentes proprietários não foram copiados para a distribuição do aplicativo.

O código upstream descreve Wine como software livre sob LGPL e mantém instruções de compilação no [README do projeto](https://github.com/wine-mirror/wine/blob/master/README.md). A [página de fontes da CodeWeavers](https://www.codeweavers.com/crossover/source) distingue os projetos FOSS usados no CrossOver e aponta seus upstreams. A distribuição macOS também possui [receitas e pacotes do mantenedor](https://github.com/Gcenx/macOS_Wine_builds). Essas referências não demonstram que uma compilação específica seja equivalente ao motor examinado.

## Formato admitido

O pacote é uma pasta com `runtime.json`, executáveis Wine e wineserver e os textos de licença indicados. O manifesto aceita o formato 1 e o formato 2; o segundo exige `minimumMacOSVersion` e pode declarar `features`. Pacotes incompatíveis com a versão do macOS são recusados antes da execução. Metadados de plataforma no formato 1 são recusados para evitar que sejam ignorados. Ambos usam identificador `org.winehq.wine`, versão, URL/revisão de origem, arquiteturas declaradas e caminhos relativos. Sua interpretação pertence a `WineRuntime`; consumidores usam os caminhos já resolvidos por esse objeto.

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

## Sincronização e opções da bottle

Em **Opções da bottle**, configure a pasta de trabalho e variáveis em JSON para novos processos. Opções do atalho têm prioridade; valores são passados literalmente, sem expansão por shell. As variáveis que escolhem prefixo e motor continuam reservadas. Duplicação e importação remapeiam a pasta de trabalho quando ela fica dentro do prefixo transferido. A biblioteca usa formato 4 e preserva um backup exato ao migrar versões anteriores.

Wine 11.21 continua sendo o padrão. Ele não oferece o protocolo MSync; não há uma opção fictícia de aceleração para esse pacote. Há um pacote **opcional**, separado, que exige macOS 26 ou posterior e Rosetta em Apple Silicon:

```sh
python3 scripts/prepare-wine-runtime.py --lock config/wine-msync-runtime-lock.json --destination .local/Runtime-WineCX-26.3
```

Selecione essa pasta como pacote Wine ao criar uma nova bottle. A seleção do motor de bottles existentes é preservada. O lock fixa o [runtime aberto WineCX](https://github.com/dappermint/winecx-gptk/releases/tag/runtime-v4.8.1), seu archive e SHA-256, o [código Wine correspondente](https://github.com/dappermint/winecx/tree/9f3f6447844add700bc0dde650e4f398fd5f69ab) e a revisão do builder. Somente a árvore `Libraries/Wine` entra no pacote final. Não são importados D3DMetal ou componentes da instalação local do CrossOver. A revisão integral das dependências para distribuição pública permanece pendente.

Nesse código, cliente e servidor leem `WINEMSYNC`: zero desativa, valores inteiros diferentes de zero ativam; a ausência desativa. O Cruzador aplica explicitamente zero no modo padrão desse pacote para não herdar um modo diferente do ambiente do macOS. **MSync** aplica `1`, e **Servidor Wine** aplica `0`. Um valor manual deve ser um inteiro decimal de 32 bits sem espaços. Não se permite ao atalho escolher um valor que discorde do modo da bottle.

Uma mudança de sincronização aguarda `wineserver -w` e só salva após sucesso não cancelado. Feche os programas da bottle para concluir a espera. Cancelar usa o encerramento do servidor dessa bottle e mantém a configuração anterior; uma falha de limpeza bloqueia novas operações até diagnóstico. A confirmação de término de uma função, isoladamente, não é tratada como sucesso do encerramento observado no contrato original.

Após compilar os testes, o cenário real opcional usa uma pasta nova e supervisão com prazo:

```sh
python3 scripts/native-smoke.py --runtime .local/Runtime-WineCX-26.3 --msync --timeout 150
```

A evidência de execução e seus limites ficam em [runtime-msync.json](../evidence/runtime-msync.json). Não há promessa de ganho de desempenho ou compatibilidade de jogos. O pacote opcional ainda não foi verificado em hardware Intel nem nos runners macOS 15 usados para o Wine padrão; a versão mínima do novo pacote é superior à desses runners.

## Cenário integrado de comportamento

O smoke do pacote independente também verifica opções globais e sobrescritas do atalho, pasta de trabalho Windows, referência de launcher, duplicação, exportação, remoção recuperável, importação e preparo da cópia. Executa o comando de prova nas três bottles e, quando há atalho 7-Zip, executa o console na importada. Exporta diagnóstico e confere os hashes das cópias. O [registro local](../evidence/runtime-library-workflows.json) conserva resultados e limites.

O supervisor exige relatórios estruturados completos e identidade compatível com o runtime e a pasta selecionados. Uma saída 0 do processo de teste sem essas observações não basta. Um resumo anterior é preservado com outro nome antes de iniciar. Falhas tentam encerrar somente os prefixos desse teste; o servidor é obtido de `runtime-control.json`, produzido pelo próprio `WineRuntime`, inclusive para caminhos personalizados. Sem metadados válidos, não há fallback para um executável presumido. O adaptador legado conserva explicitamente a limitação de limpeza automática.

`--output-root` permite escolher onde reter os resultados. O registro de supervisão distingue saída do teste, prazo excedido, erro do relatório e resultado das tentativas de limpeza. A coleta de CI preserva caminhos e hashes em `evidence-index.json`; não achata logs com nomes iguais e não inclui binários, prefixos ou a cópia bruta da biblioteca.

Os testes de apresentação usam armazenamento e histórico recentes isolados. Pedidos recebidos durante outra tela ou operação aguardam revisão, e ações atrasadas de uma tela não fecham outra. Isso não substitui validação visual da interface.
