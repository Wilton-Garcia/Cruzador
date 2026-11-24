# Lógica Python empacotada

Foram decodificados os 50 arquivos `.pyc` diretamente presentes em `Contents/SharedSupport/CrossOver/lib/python`, totalizando 1.529 objetos de código CPython 3.13. O [catálogo](../evidence/python-disassembly-catalog.json) identifica os arquivos originais e seus hashes; [cada módulo](../evidence/python-disassembly/) preserva nomes, constantes, instruções, destinos de salto e tabelas de exceção.

O analisador usa a biblioteca Python 3.13 distribuída no aplicativo como ferramenta, num processo próprio com inicialização isolada, sem site de usuário, sem variáveis de ambiente Python e sem escrita de bytecode. O interpretador e sua biblioteca padrão executam o script de inspeção do Cruzador. Os módulos de negócio são lidos por `marshal` e `dis`; não são importados nem executados. Não há instalação de outro Python nem alteração dos arquivos do aplicativo.

O host C e o script são código do projeto. Há verificações de entrada com magic incompatível, bytes excedentes, preservação de nomes Unicode, saltos/tabelas de exceção e um módulo de teste que criaria um arquivo se fosse executado. A inspeção não cria esse arquivo. O Python embarcado não inclui unittest; as verificações usam assertivas próprias e falham pelo status do processo.

A serialização distingue constantes de símbolos derivados do interpretador. Operandos que referenciam objetos de código usam nome, arquivo e linha, sem persistir endereços de memória temporários de `repr`. Duas execuções completas produziram hashes idênticos. O verificador cruza ainda 345 digests de objetos de código com os metadados REA dos cinco módulos examinados anteriormente.

## Fluxos recuperados por leitura das instruções

### Criação e cópia

`bottlemanagement.create_bottle` constrói o comando com `_bottle_tool()`, `--bottle`, nome, `--create`, `--template`, template e `--install`. Se appid foi fornecido, acrescenta `--param` e a identificação do aplicativo criador. A chamada de `cxutils.run` recebe o ambiente explicitamente e captura stderr; o resultado da função contém `retcode == 0` e o texto de erro. A cópia usa `--copy` e também `--install`.

A renomeação verifica conflito, remove a integração do nome anterior, renomeia o diretório e reinstala com novo UUID; preserva a escolha de default quando aplicável. Essa sequência não estabelece rollback integral após uma falha tardia. Ela é evidência do original, não uma recomendação para reproduzir fragilidade no Cruzador.

Fonte: `evidence/python-disassembly/bottlemanagement.json`, objetos `create_bottle`, `copy_bottle` e `rename_bottle`.

### Persistência de configuração

`BottleWrapper.set_config_value` solicita a configuração gravável. Quando ela não existe, registra aviso e retorna. Quando existe, adquire o bloqueio, atualiza a chave da seção e chama `save_and_unlock_file`. Os setters gráficos escrevem `EnvironmentVariables/CX_GRAPHICS_BACKEND`, recarregam a informação gráfica e notificam mudança da bottle. A escolha Auto escreve string vazia; as outras escolhas escrevem `d3dmetal`, `dxmt`, `dxvk` ou `wined3d`.

Fonte: `bottlewrapper.json`, objetos `BottleWrapper.set_config_value` e `BottleWrapper.set_graphics_backend_*`. A implementação interna do bloqueio e da escrita aparece separadamente em `cxconfig.json` e requer seus próprios contratos de falha.

### MSync e ciclo de operação

`enable_msync` e `disable_msync` suspendem a bottle e solicitam encerramento com callback. O callback altera a configuração e retoma a bottle. O caminho que executa o encerramento passa por operações de bottle e deve ser considerado junto da propagação de falhas; observar a instrução de registro de callback não prova que ele será chamado em todo erro.

A função de encerramento em `bottlemanagement` verifica primeiro se há execução ativa. Se houver, chama Wine com `--no-update --wl-app wineboot.exe -- --end-session --shutdown --force --kill` no escopo da bottle e usa o status retornado.

Fonte: `bottlewrapper.json`, `BottleWrapper.enable_msync`, `BottleWrapper.disable_msync` e respectivos callbacks; `bottlemanagement.json`, `quit_bottle`.

### Capacidades de uma bottle

A leitura dos saltos distingue capacidades:

- `get_can_run_commands`: `(up_to_date or not is_managed) and not is_busy and not is_disabled`.
- `get_can_edit`: `up_to_date and not is_busy and not is_managed`.
- `get_is_usable`: percorre overrides de estado e recusa estados fora do conjunto admitido naquele método.

Validade, possibilidade de execução e editabilidade são conceitos diferentes. O protótipo atual tem apenas estados preparing/ready/failed e não reproduz essa distinção completa.

### Receitas, instalação e dependências

A desassemblagem inclui `InstallTask`, `TargetBottle`, o motor `Engine`, parsers de perfil, resolução de mídia, downloads, configurações e fila de operações. Isso remove a limitação anterior de possuir apenas nomes e constantes. Não representa interpretação semântica integral das 1.529 funções nem recuperação do código-fonte original. Os caminhos necessários à implementação devem ser ligados a contratos e exercitados em cenários controlados.

## Verificação e limites

`python3 scripts/verify-python-disassembly.py` verifica os artefatos já preservados. `python3 scripts/disassemble-application-python.py` recompila o host de inspeção e relê a instalação selecionada, executando primeiro as verificações de fronteira. Não é necessário reler o aplicativo para consultar os resultados versionados.

O catálogo cobre módulos de negócio de primeiro nível; módulos aninhados, bibliotecas nativas, interpretador e outros runtimes não estão incluídos nessa seleção. A desassemblagem não observa execução do CrossOver, não garante compatibilidade Windows e não comprova independência do produto.
