# Cenários controlados no CrossOver original

A execução usa ferramentas originais em uma bottle nova, sob `.local/original-scenarios/<UUID>`, com `CX_BOTTLE_PATH`, `CX_BOTTLE` e `WINEPREFIX` explícitos. A bottle Steam do usuário não foi usada nestes comandos. Os argumentos, hashes dos executáveis, saídas e status estão em [original-workflows.json](../evidence/runtime/original-workflows.json).

| Cenário | Resultado observado |
| --- | --- |
| Criar bottle Windows 10 64-bit | Status 0; system.reg e drive_c presentes |
| Repetir criação com o mesmo nome | Status 1 |
| Consultar status após o conflito | Status 0; saída preservada |
| Executar cmd.exe com marcador | Status 0 e CRUZADOR_ORIGINAL_OK |
| Executar cmd.exe /c exit 7 | Status 7 |
| Solicitar programa inexistente | Status 1 |
| Executar novo comando após os erros | Status 0 e CRUZADOR_RECOVERED_OK |
| Aguardar servidor da bottle | Status 0 |

O registro comprova esses resultados no motor instalado. Não comprova instalação de qualquer EXE/MSI, funcionamento de jogos, eliminação de todos os arquivos de uma instalação cancelada ou independência do CrossOver.

O cancelamento gráfico de uma instalação Steam já havia sido observado, após autorização do usuário, na tarefa de catalogação: a interface confirmou o cancelamento e manteve a bottle visível. Esse resultado permanece em `ui-observations.json`, separado dos cenários novos.

## Captura e limpeza

A tentativa inicial com `rea capture-process` não lançou o alvo: o módulo nativo PTY foi rejeitado pela validação de assinatura do Node utilizado. A evidência de falha registra PID indisponível e grupo de processo não criado. Nenhuma assinatura ou proteção foi alterada para contornar isso.

Os cenários foram então executados por subprocessos supervisionados, com saída diretamente em arquivo e prazo de execução. O registro salva apenas o ambiente explicitamente selecionado, não o ambiente herdado inteiro. Cada grupo iniciado pelo script tem tratamento de prazo; os artefatos e o prefixo são preservados para diagnóstico. A espera final é restrita ao servidor dessa bottle.

Não houve censo integral de processos, gravação de terminal ou prova de encerramento de todo helper desacoplado. A espera do wineserver não foi transformada nessa afirmação mais forte. Os arquivos de teste não foram removidos.

Para conferir os resultados preservados: `python3 scripts/verify-original-workflows.py`. Para executar novos cenários no aplicativo original instalado: `python3 scripts/observe-original-workflows.py`.
