# Avaliações de compatibilidade

Em **Gerenciar → Compatibilidade**, escolha um aplicativo, informe a versão, o resultado e os passos testados. O registro é uma observação manual do usuário: identifica aplicativo e bottle, hash SHA-256 do executável selecionado, motor, versão do runtime incluído quando conhecida, macOS e data. A nota descreve o alcance do teste; o Cruzador não infere compatibilidade geral a partir da execução de um processo.

Os registros ficam em `Compatibility` na biblioteca. Novas observações preservam as anteriores. **Arquivar** move a avaliação para `Compatibility/Archived`, permitindo conservar a origem sem exibi-la na matriz ativa. Um arquivo inválido causa erro e permanece intacto.

**Exportar todas as avaliações** produz uma matriz JSON independente, incluindo notas e caminhos do motor; escolha um nome de arquivo novo. O compartilhamento desse arquivo é manual. Nenhum registro é enviado automaticamente, e não há servidor central ou integração com avaliações do CrossOver.
