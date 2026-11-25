# Publicações e bottles gerenciadas

**Gerenciar → Publicar cópia versionada** exporta um pacote `.cruzadorbottle` completo com identidade de publicação, revisão e inventário SHA-256 dos arquivos. Links são registrados pelo destino literal e não percorridos. A operação aguarda os programas Wine encerrarem, como a exportação normal. O pacote inclui dados da bottle; revise seu conteúdo antes de compartilhá-lo.

Para uma revisão seguinte, use **Publicar nova revisão**, selecione a publicação anterior e escolha um destino novo. A publicação anterior precisa estar íntegra. Sua identidade é mantida e a revisão aumenta; os pacotes anteriores não são sobrescritos.

**Receber publicação** valida todos os arquivos e registra o vínculo local. A bottle recebida ganha identidade própria e precisa ser preparada antes da execução. **Atualizar de publicação** exige uma revisão superior da mesma publicação e cria outra bottle; a anterior, seus arquivos e alterações do usuário são preservados. Não há merge automático dos dados pessoais entre revisões. O vínculo em `Managed` registra origem, revisão, hash do manifesto e bottle anterior.

O compartilhamento é por arquivos e pastas locais ou volumes montados, sem serviço central. Hashes detectam alterações no pacote em relação ao manifesto; não autenticam o editor da publicação. Escolha uma origem confiável antes de executar seus programas Windows. Pacotes comuns continuam disponíveis por Importar/Exportar, sem vínculo gerenciado.
