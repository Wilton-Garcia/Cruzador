# Contratos recuperados

O [registro estruturado](../evidence/recovered-contracts.json) descreve 14 contratos Python e duas fronteiras nativas, com entradas, retornos observados, efeitos, falhas, incertezas e referências por digest do bytecode. São descrições do original; não declaram que o Cruzador já implementa essas operações.

A leitura separa identidade e nome de exibição, validade de prefixo e editabilidade, pedido de configuração e disponibilidade real do backend, cancelamento solicitado e limpeza concluída. Os cenários executados comprovam apenas os casos vinculados a cada contrato.

Criação e cópia retornam um booleano derivado do status do subprocesso junto do texto de erro. Arquivamento e restauração usam operações próprias do cxbottle. Renomear envolve várias etapas e não teve rollback completo estabelecido. Gravar configuração pede um objeto gravável, bloqueia, altera e salva; a ausência desse objeto não é tratada pelo original como uma gravação bem-sucedida.

Há uma diferença especialmente importante no ciclo de MSync: a finalização de encerramento marca `last_quit_failed` quando falha, mas chama o callback nos dois casos. Portanto, receber esse callback não significa encerramento bem-sucedido. A sequência que troca a configuração deve ser interpretada junto desse estado, e não copiada como se o callback fosse uma confirmação de sucesso.

O cancelamento de uma operação marca estado e altera a fila; isso não prova, por si só, término de subprocessos. No controlador nativo de comandos, a conclusão exige o término do processo e os resultados das saídas. A fronteira carregador/ntdll permanece separada do gerenciamento de tarefas da interface.

O registro deixa explícitos os pontos que ainda precisam de validação de execução ou interpretação mais profunda, em vez de transformar falhas ou estados desconhecidos em ausência. Verificação de proveniência: `python3 scripts/verify-recovered-contracts.py`. Esse comando não comprova automaticamente a interpretação semântica dos contratos.
