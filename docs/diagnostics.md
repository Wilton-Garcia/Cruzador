# Diagnóstico local

**Diagnóstico…**, no rodapé da biblioteca, exporta uma pasta local `.cruzadordiagnostics`. A ação também está disponível quando a biblioteca não pôde ser aberta ou há uma limpeza pendente. Não executa Wine, não instala componentes e não envia dados.

O relatório `report.json` inclui a versão do macOS e arquitetura do processo, a origem e o estado da biblioteca, as bottles selecionadas, a estrutura dos prefixos e os fatos de manifesto dos motores. A seleção de uma bottle limita essa parte do relatório. Motores externos ficam explicitamente não inspecionados; ausência de execução não vira uma afirmação de que funcionam. Validar o manifesto do pacote não verifica todo o inventário nem o comportamento de seus binários.

Há duas inclusões opcionais, desativadas inicialmente:

- **Cópia exata de library.json**: inclui toda a biblioteca, mesmo quando o relatório está limitado a uma bottle. Preserva os bytes observados, inclusive de um JSON inválido, com seu SHA-256. Pode conter caminhos, argumentos e variáveis explicitamente salvas.
- **Arquivos da pasta Logs**: inclui os arquivos regulares dessa pasta de todas as bottles. Cada cópia recebe um hash dos bytes exportados. Links não são seguidos; arquivos ignorados, falhas e cópias parciais são identificados no relatório. A captura não reúne o ambiente herdado nem os logs gerais do sistema.

Revise os arquivos antes de compartilhar. A exportação é local; não existe envio automático. O relatório distingue o que foi solicitado do que foi efetivamente incluído. Um destino existente ou situado dentro da biblioteca é recusado para preservar os dados e impedir cópia recursiva. Uma exportação que falha preserva seu estágio e informa o caminho.

## Observações e estados desconhecidos

`LibraryStore.observe()` é o responsável pela leitura e interpretação da biblioteca: distingue arquivo ausente, conteúdo válido e conteúdo inválido com seus bytes de origem. Erros de leitura continuam erros; não produzem uma biblioteca vazia. O diagnóstico pode registrar essa falha mesmo sem conseguir obter os bytes. Dados de bottles desconhecidos não são substituídos por uma lista vazia.

A estrutura do prefixo distingue ausência, incompletude, inicialização e disponibilidade desconhecida, por exemplo um registro existente sem permissão de leitura. A interface conserva essa distinção. Preparação não inicia quando não é possível verificar os arquivos. Prontidão estrutural continua separada da conclusão registrada de preparo ou encerramento.

## Encerramento não confirmado

`BottleOperationRecovery` preserva na biblioteca o estado interrompido, a falha e o log quando o supervisor não confirma a limpeza. Isso se aplica à espera para trocar sincronização, instalação e manutenção; a preparação também preserva sua falha. Reabrir o aplicativo não torna a bottle pronta por perder o bloqueio que estava em memória.

Se a gravação do diagnóstico falhar, `BottleRecoveryError` conserva os fatos da falha original de limpeza junto do motivo da falha de persistência. A interface mantém a opção de repetir o encerramento. Ela não converte uma falha de gravação em sucesso nem descarta as fases observadas. Resolver a limpeza não marca automaticamente o prefixo como pronto.

Os testes verificam permissões, fonte inválida, cópia sem seguir links e a recuperação dos fluxos públicos de preparo, instalação e manutenção, inclusive quando os metadados mudam durante a operação. Esses cenários de falha usam subprocessos controlados de fixture. A [exportação observada de um prefixo real](../evidence/runtime-diagnostics.json) verifica os bytes originais e hashes exportados; não estabelece compatibilidade de aplicativos Windows ou validação visual da tela.
