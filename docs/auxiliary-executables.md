# Executáveis auxiliares e fronteira do motor

A inspeção identificou `wineloader` e `wineserver` como Mach-O x86_64, `lib/wine/x86_64-unix/ntdll.so` como biblioteca Mach-O x86_64 e `lib/wine/x86_64-windows/winewrapper.exe` como PE32+ x86_64. Identidades, dependências e tabelas de importação estão preservadas no [relatório estruturado](../evidence/auxiliary-boundaries.json).

O carregador tem um inventário Hopper de 32 entradas exportadas como pseudocódigo, incluindo stubs e auxiliares. A entrada `0x100000670` recupera sua localização, constrói candidatos para `ntdll.so`, carrega a biblioteca e resolve `__wine_main`. A busca usa também `WINEDLLPATH` quando os caminhos anteriores não resolvem. Isso estabelece uma fronteira entre carregador e implementação nativa, não uma implementação completa das APIs Windows no carregador.

A entrada `__wine_main` de ntdll foi decompilada a partir do símbolo exportado, endereço `0x1fb90`. O pseudocódigo mostra tratamento de `WINELOADERNOEXEC`, ajuda/versão, inicialização nativa e integração com o run loop CoreFoundation. O texto de versão presente nesse caminho é `wine-11.0-8726-g2e2f5fca349`; é uma declaração recuperada do artefato, não autenticação de uma correspondência exata com um repositório público.

A entrada do wineserver registra tratamento de sinais, opções e limites de descritores, antes de chamar rotinas internas sem nomes recuperados. A busca literal `_main` não encontrou correspondência no inventário; isso não significou ausência de entrada. A análise foi continuada por `EntryPoint`, sem inventar um símbolo. A evidência preserva essa busca negativa limitada.

O script distribuído `bin/wine` prepara `WINEPREFIX`, `WINESERVER`, `WINELOADER`, `WINEDLLPATH` e `WINEWRAPPER`; o último aponta para o executável PE Wine que recebe opções de execução. Os caminhos de WineArch, GStreamer e bibliotecas gráficas são configurados antes do lançamento. O servidor e o carregador não são intercambiáveis com esse script de preparação.

As inspeções Mach-O e PE foram feitas sem executar esses alvos. A decompilação usa Hopper. Não houve recuperação integral do protocolo do servidor, do kernel Win32, de todos os syscalls ou de renderizadores. Tais implementações devem ser tratadas separadamente na escolha e validação de um motor independente.

A CLI REA local usa o launcher já existente do Limpador, com Node compatível. A primeira tentativa sem acesso aos caches Xcode falhou na compilação do supervisor de processos; a execução autorizada com esse acesso produziu os artefatos preservados. Não foi instalado outro runtime nem alterada a configuração MCP.

Verificação: `python3 scripts/build-auxiliary-boundaries.py --check`.
