# Preferências de instalação e cache

Em **Configurações → Instalação e cache**, escolha o modo padrão do assistente MSI, a política de downloads das receitas e a pasta de cache. Campo vazio usa `Downloads` na biblioteca. Trocar a pasta não move nem apaga os arquivos da anterior. Salve a seleção antes de inspecionar ou limpar o cache.

O assistente MSI continua permitindo escolher outro modo por instalação. EXEs não recebem flags silenciosas genéricas, e receitas preservam os argumentos e o modo do catálogo. **Usar somente instaladores em cache** recusa uma receita cujo arquivo não esteja disponível no cache escolhido, sem iniciar download. Arquivos reutilizados passam pela mesma validação de tamanho e SHA-256; um arquivo alterado é preservado e recusado.

`installer-preferences.json` é versionado. Dados inválidos ou futuros impedem instalar usando um padrão presumido. Salvar uma escolha explícita mantém backup dos bytes anteriores em `Backups`; salvar sem mudança não cria novas cópias.

A inspeção reconhece os recibos gravados pelo cache e distingue payload presente, ausente e indisponível. O recibo prova o vínculo do arquivo com o cache; a integridade do payload é verificada ao reutilizá-lo. Um payload modificado pode continuar sendo um arquivo próprio que você deseja remover.

**Limpar cache para a Lixeira** pede confirmação e move somente arquivos reconhecidos. O payload é movido antes de seu recibo. Se essa etapa falhar, ou se o caminho tiver virado uma pasta/ficar indisponível, o recibo permanece para permitir nova tentativa. Outros arquivos, recibos desconhecidos e downloads parciais são preservados. Limpeza parcial informa os erros e registra origens/destinos conhecidos em `Logs/cache-cleanup-UUID.json`. A Lixeira do macOS permite recuperar os arquivos; ela não é esvaziada pelo Cruzador.

O [registro da validação](../evidence/runtime-cache-maintenance.json) conserva o teste com dois arquivos novos descartáveis na Lixeira real e um arquivo não reconhecido preservado. Os testes de fonte também cobrem resultados mistos, manutenção da propriedade após falha, tipo de payload inválido, somente-cache e recuperação de preferências desconhecidas. Não há validação de todos os volumes externos ou políticas de permissão do macOS.
