# Receitas próprias

**Receitas** instala uma descrição incluída no aplicativo, na bottle selecionada. O catálogo atual começa com 7-Zip x64 26.06. Ele contém a origem oficial, release, nome do arquivo, tamanho e SHA-256 publicados pelo fornecedor, modo do instalador, argumentos e atalhos esperados. Não importa nem executa receitas CrossTie do CrossOver.

O formato 1 de `config/recipes.json` é a fonte do catálogo do aplicativo e dos assets de validação. IDs duplicados, dependências ausentes, ciclos, artefatos sem HTTPS ou digest válido e caminhos de atalhos fora do formato relativo são recusados antes de executar. Dependências compartilhadas aparecem uma vez no plano e são instaladas antes de seus consumidores. Os argumentos são dados de uma instalação Windows; o formato não aceita comandos arbitrários do macOS.

O download usa o tamanho declarado como limite e só é admitido no cache depois de conferir tamanho e SHA-256. Os arquivos ficam em `Downloads/<digest>/<nome>` na biblioteca. Um arquivo em cache é verificado novamente antes de usar; alterações são recusadas e preservadas para diagnóstico. O recibo do download registra a URL de origem declarada, digest, tamanho e data, sem copiar o ambiente do processo. Links temporários de autenticação usados pelo transporte não são registrados.

A receita usa o mesmo serviço e histórico do instalador local. As opções silenciosas do 7-Zip vêm do [FAQ oficial](https://www.7-zip.org/faq.html). A interface mostra seus argumentos antes da instalação. Não são deduzidas opções para outros instaladores. O histórico conserva ID da receita e a origem/digest declarados do artefato usado.

Depois que o instalador conclui, os executáveis esperados são conferidos e seus atalhos são cadastrados. Atalhos existentes com o mesmo caminho e argumentos são mantidos. Falha em uma dependência interrompe os passos seguintes; uma instalação já executada não é apagada como rollback. Repetir a receita pode executar novamente os instaladores: presença de arquivos ou um histórico antigo não é tratada como prova de que todas as dependências continuam válidas.

Cancelar interrompe o download ou solicita a limpeza do motor para a etapa em execução. O serviço verifica cancelamento antes de iniciar outro instalador ou registrar atalhos. O catálogo é pequeno e próprio; não representa cobertura do catálogo comercial original, de redistribuíveis Microsoft ou de dependências de jogos em geral.

A execução local completa, preservada em `evidence/runtime-recipes.json`, baixou e instalou a receita e lançou o console pelo atalho gerado. A suíte padrão usa fixtures para ordem e falhas de dependências. O cenário ampliado em Intel atingiu o antigo prazo total de 120 segundos após inicialização e reparo, antes de registrar a conclusão do primeiro comando. O CI agora registra inícios por fase e usa um prazo explícito de 300 segundos para medir esse cenário; essa alteração não estabelece sucesso Intel. CPU e pico de memória da família de processos não foram medidos.

A [validação instrumentada posterior](../evidence/runtime-recipes-ci.json), no commit `a462112`, passou em Intel e Apple Silicon, incluindo MSI, receita e execução de atalhos. O timeout anterior permanece como observação histórica, sem representar o estado dessa execução posterior.
