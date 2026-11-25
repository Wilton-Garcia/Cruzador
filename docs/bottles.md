# Bottles e preparação

Cada bottle tem UUID, nome de exibição, motor escolhido, data de criação e atalhos próprios. O nome não compõe o caminho do prefixo: renomeá-lo não altera sua identidade. Os arquivos ficam em `Bottles/<UUID>` dentro da biblioteca.

`BottleLifecycle` cria o registro e controla preparação e reparo. Ele salva o estado em preparação antes de executar o motor, aguarda a finalização e só registra prontidão quando o resultado é zero e existem `drive_c` como pasta e `system.reg` como arquivo legível. Essa inspeção estrutural não comprova a integridade integral do registro ou a compatibilidade de aplicativos.

Falhas preservam o prefixo, o erro e o caminho do log no registro da bottle. Preparar novamente tenta inicializar os arquivos incompletos sem apagar o conteúdo. Reparar uma bottle inicializada executa a atualização Wine (`wineboot --update`) e aguarda seu servidor; não reinstala aplicativos nem restaura arquivos de um backup.

Na abertura do aplicativo, uma preparação que ficou sem conclusão registrada passa a interrompida. Isso significa conclusão desconhecida: não prova que processos antigos tenham terminado. Nenhum processo é encerrado por essa recuperação. A operação exige diagnóstico dos logs antes de uma nova tentativa.

O estado persistido e a presença de arquivos são fatos separados. Uma bottle registrada como pronta pode ter perdido arquivos; a interface bloqueia execução nesse caso. Um prefixo com arquivos, mas com preparação falha, também permanece bloqueado até concluir nova preparação. O backup do manifesto é preservado antes de alterações.

Os testes de ciclo de vida verificam criação, reparo, falha, retomada, preservação de arquivos e recuperação idempotente. O cenário opcional do pacote real usa o mesmo fluxo de produção para criar e reparar antes de executar programas Windows de 32/64 bits.

## Manutenção e transferência

O menu **Gerenciar** oferece renomeação, duplicação, exportação e remoção. **Importar bottle** recebe uma pasta `.cruzadorbottle` com `bottle.json` e `Prefix`. É um formato próprio, sem compressão; não é o arquivo de backup do CrossOver. O motor Wine precisa estar disponível e seus programas devem ser fechados: cópia, exportação e remoção aguardam o servidor da bottle antes de alterar arquivos. A espera ainda não possui cancelamento pela interface.

Duplicar gera outro UUID e ajusta atalhos e links absolutos que apontavam para o prefixo original. Links relativos e destinos externos são preservados como links: arquivos fora do prefixo não são incluídos no pacote. Argumentos arbitrários dos atalhos não são reinterpretados como caminhos. A importação copia o conteúdo para outro UUID, usa o motor escolhido nas configurações e exige nova preparação antes de executar. A origem permanece intacta.

Remover move o registro e o prefixo para `Removed/<UUID>.cruzadorbottle`; não os apaga definitivamente. Um pacote com prefixo inicializado pode ser importado novamente. Preparações incompletas ou registros sem prefixo permanecem disponíveis para diagnóstico nessa pasta, mas não satisfazem a validação de importação. Transferências que falham preservam arquivos parciais no caminho informado pelo erro. Não se deve apagá-los antes de conferir a origem e o manifesto da biblioteca.

Esses fluxos são próprios do Wine independente. O adaptador CrossOver permanece para investigação e execução legada; a manutenção não declara suporte a seus formatos ou à transferência de suas bottles gerenciadas.

## Persistência e atualização do formato

A biblioteca usa o formato 2. A leitura de um manifesto 1 permanece suportada; ao migrar ou salvar, o Cruzador preserva seus bytes originais em `library-v1.json.bak` antes de gravar o formato atual. Esse backup de migração não é substituído nas próximas gravações. O `library.json.bak` continua sendo o backup da alteração anterior. Repetir a migração não regrava um manifesto já atualizado.

Versões futuras, JSON malformado, IDs duplicados e referências a uma bottle padrão inexistente impedem a gravação. O aplicativo mantém os arquivos para diagnóstico. **Gerenciar → Usar como padrão** salva a bottle preferida para a próxima abertura; removê-la limpa essa preferência.

A seleção de motor em preferências usa um único valor versionado. Os antigos campos separados continuam legíveis e são preservados em backup quando o usuário salva a seleção atual. Um valor novo inválido não usa os campos antigos como fallback. Essas migrações não movem prefixos nem substituem o motor registrado em bottles existentes.

## Lançamento por atalho

Um atalho salva executável, argumentos, pasta de trabalho opcional e variáveis de ambiente. A edição preserva sua identidade. Cada linha de argumentos é transmitida literalmente ao motor, sem shell macOS; comandos dentro de `cmd.exe` continuam sujeitos à interpretação do próprio Windows. As variáveis usam um objeto JSON de nomes e valores de texto. `WINEPREFIX`, `WINESERVER`, `WINELOADER`, `WINEDLLPATH`, `CX_BOTTLE` e `CX_BOTTLE_PATH` pertencem à seleção do motor e não podem ser substituídos por um atalho.

A pasta deve existir e ser absoluta; vazio mantém o comportamento herdado do processo. O arquivo Windows deve existir e ser regular. Opções são revalidadas no lançamento, pois arquivos e pastas podem mudar depois do cadastro. Atalhos antigos, sem opções, mantêm argumentos e comportamento anteriores. Ao transferir uma bottle, pastas de trabalho internas são remapeadas junto dos executáveis; variáveis e argumentos não são reinterpretados como caminhos.
