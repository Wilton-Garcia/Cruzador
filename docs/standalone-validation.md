# Execução sem CrossOver nas pastas inspecionadas

O [registro de CI](../evidence/runtime-standalone-ci.json) identifica o commit e os artefatos de duas máquinas macOS 15: arm64 e x86-64. Os dois jobs concluíram com sucesso. Antes e depois dos testes, `verify-standalone-environment.py` examinou `/Applications`, `/System/Applications` e `~/Applications`, sem encontrar o bundle CrossOver ou seu identificador, e sem erros de inspeção nesses runners.

Nas duas máquinas, o motor Wine fixado executou os cenários integrados da biblioteca, comandos Windows de 32/64 bits, cancelamento e recuperação, instalação MSI e receita 7-Zip, Plink x86/x64 e SQLite x64 com persistência e verificação de integridade. O supervisor levou aproximadamente 130 s no arm64 e 230 s no Intel. CPU e memória da família de processos não foram medidas. O build universal e a verificação da assinatura local também passaram.

A inspeção é limitada às pastas nomeadas. Não é uma prova de ausência de qualquer binário renomeado em todo o disco nem um censo de processos. O controle local detectou `/Applications/CrossOver.app`; uma identidade desconhecida por erro de leitura não é tratada como ausência. O teste verifica a identidade de bundles pelo nome e por `Info.plist`.

Os relatórios de runtime, os registros antes/depois e os hashes dos membros do artefato são preservados. O commit de CI antecede alterações posteriores de ícone, empacotamento e auditoria; não se atribui a elas a mesma verificação remota. Nenhum desses resultados estabelece equivalência integral do produto ou compatibilidade arbitrária com jogos.
