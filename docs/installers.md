# Instalação de programas

**Instalar programa** permite escolher um EXE ou MSI local e revisar a bottle de destino, argumentos, pasta de trabalho e ambiente antes de executar. Os argumentos usam uma entrada por linha; o Cruzador não adivinha opções silenciosas de instaladores EXE. A pasta do arquivo é o diretório de trabalho padrão, permitindo que o instalador encontre arquivos auxiliares próximos.

Para MSI, o usuário pode escolher interface interativa, progresso sem perguntas ou ausência de interface. O comando solicita `/norestart` e log detalhado com `/L*V`; argumentos adicionais continuam sendo escolhas explícitas do usuário. O log MSI fica na pasta `Logs` da biblioteca, separado do log do processo. O formato e a codificação da saída pertencem ao instalador.

## Inspeção e limites

`WindowsFileInspection` verifica o arquivo regular e seu tipo: assinatura MZ, deslocamento PE dentro do arquivo e assinatura PE para EXE; assinatura de armazenamento composto para MSI. A assinatura CFB é descrita na [especificação da Microsoft](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/05060311-bfce-4b12-874d-71fd4ce63aea). Isso não valida as tabelas do banco MSI, a estrutura completa do PE, uma assinatura digital ou a segurança do programa.

Tamanho e data de modificação são registrados e conferidos antes de executar. Esses metadados não são um digest do arquivo nem uma garantia de que o conteúdo não possa mudar depois da conferência. O usuário deve selecionar um arquivo estável. O instalador recebe o caminho escolhido, preservando os arquivos auxiliares e a origem local.

## Histórico e resultado

O serviço registra o início antes de executar e conserva inspeção, opções explícitas, argumentos, logs, fases e resultado. Uma instalação sem conclusão registrada passa a conclusão desconhecida ao reabrir o aplicativo. Cancelamentos passam pelo mesmo supervisor e encerramento da bottle usados no lançamento de programas.

Código zero significa que o processo instalador terminou com sucesso; não demonstra que um aplicativo específico foi instalado ou que um processo separado iniciado por ele tenha concluído. Códigos diferentes de zero ficam como resultado não confirmado, com o valor observado no macOS. O código Windows completo não é reconstruído a partir dele: a [conversão de saída do Wine](https://github.com/wine-mirror/wine/blob/wine-11.21/dlls/ntdll/unix/thread.c#L81) trata a fronteira Unix, que pode perder informação. Assim, um valor como 194 não é automaticamente declarado como pedido de reinício 3010.

O histórico exibe os cinco registros mais recentes; os demais permanecem no manifesto. Atalhos e histórico são fatos distintos: conclua a instalação e cadastre o executável instalado para lançá-lo. A descoberta automática e o catálogo de receitas pertencem a fluxos separados.

## Cenários de validação

O teste nativo admite `--installer-msi` com o MSI x64 do 7-Zip fixado em `config/recipes.json`. `python3 scripts/prepare-validation-assets.py --asset sevenzip-msi` baixa o asset oficial e verifica tamanho e SHA-256 publicados no release. O teste exige a conclusão do instalador, a presença de `7z.exe` dentro do prefixo e sua execução; também verifica a rejeição de um pacote inválido. Downloads e prefixos de teste não entram no Git.

Uma tentativa separada com `winemono-support.msi` do próprio pacote provocou uma falha de memória no Wine. O [registro da falha](../evidence/runtime-msi-support-failure.json) preserva a observação e o encerramento da bottle isolada. A causa não foi estabelecida. Esse resultado permanece uma limitação de compatibilidade, sem ser convertido em sucesso ou repetido sem mudanças.
