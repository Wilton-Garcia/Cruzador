# Comparação selecionada com o original

O [registro de comparação](../evidence/runtime-original-comparison.json) vincula o CrossOver 26.3 ao SHA-256 do executável já investigado e conserva hashes de cada ferramenta e log. A execução original usa uma bottle privada nova, sem usar a bottle Steam. Os resultados independentes vêm de uma execução retida separada, identificada pelo hash do relatório; não são apresentados como estado simultâneo.

Foram observados comandos Windows de 32/64 bits com marcadores e variável explícita, retorno 7, programa ausente, instalação silenciosa do MSI 7-Zip 26.06 x64, execução do console instalado, MSI inválido, comando depois dos erros e espera do servidor. Os comandos, o MSI e seus caminhos permanecem disponíveis nos registros. Os dois motores concluíram os casos positivos e rejeitaram o MSI inválido; o status Unix observado desse erro foi 91 nos dois motores. Não se infere o código MSI Windows completo a partir do status Unix.

A observação não estabelece equivalência integral de UI, desempenho ou jogos. O Cruzador conserva formatos próprios de biblioteca, launcher e transferência, valida arquivos locais antes de executar e exige confirmação de encerramento antes de trocar sincronização. O callback encontrado no original não é usado como prova de sucesso de limpeza.

A janela atual do Cruzador também foi inspecionada por imagem e árvore de acessibilidade. Foram conferidos a biblioteca, busca vazia e restauração, opções da bottle e diálogo de criação com Wine incluído. Não foram salvas opções nem preparados ambientes por esses diálogos. Isso não estabelece teste completo de teclado, VoiceOver ou todos os fluxos gráficos. A inspeção anterior indisponível foi superada, sem atribuir uma causa não comprovada ao erro da ferramenta.

Para repetir os casos originais após compilar e obter um relatório independente completo:

```sh
python3 scripts/compare-original-runtime.py
```

O observador recusa um executável original diferente da identidade investigada, retém todos os dados e limita cada comando. A espera do servidor permanece restrita à bottle escolhida e não é um censo de helpers desacoplados.
