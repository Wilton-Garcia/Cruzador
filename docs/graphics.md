# Gráficos da bottle

**Gerenciar → Opções da bottle** permite manter o padrão do motor ou solicitar WineD3D/OpenGL e WineD3D/Vulkan. Vulkan é experimental. As opções explícitas foram integradas ao pacote Wine 11.21 do Cruzador; outros motores mantêm o padrão até terem essa integração verificada.

A opção usa `WINE_D3D_CONFIG` nos novos processos. O [código upstream Wine 11.21](https://github.com/wine-mirror/wine/blob/wine-11.21/dlls/wined3d/wined3d_main.c) define `renderer=gl` e `renderer=vulkan` e dá precedência ao ambiente sobre o registro. Uma variável explicitamente configurada no atalho ou no instalador tem precedência sobre a seleção da bottle e é preservada literalmente. O padrão não injeta uma escolha de renderer.

Antes de aceitar uma opção explícita, `GraphicsConfiguration` observa as DLLs WineD3D de 32/64 bits e seus cabeçalhos PE. Para Vulkan, confere também as DLLs WineVulkan, o manifesto ICD e a biblioteca por ele indicada dentro do pacote. Componentes ausentes, formato desconhecido ou caminho fora do pacote deixam a opção indisponível, preservando as observações parciais na resposta. Isso não comprova que a GPU consiga inicializar o backend.

Salvar modifica os metadados com backup; não substitui DLLs nem altera um processo Windows em execução. Feche e abra o programa para aplicar a escolha. Comandos de encerramento não dependem da configuração gráfica continuar válida, permitindo limpar uma bottle mesmo quando um componente gráfico está ausente.

A biblioteca passa ao formato 3 para registrar a configuração. Manifestos 1 e 2 continuam legíveis e recebem backup permanente da versão anterior quando migrados. As configurações existentes sem seleção explícita continuam usando o padrão do motor.

Os testes verificam os componentes, arquitetura PE, persistência, precedência do atalho e limpeza com gráficos indisponíveis. O cenário opcional real observa o ambiente recebido por `cmd.exe` e executa DxDiag com limite de 30 segundos por observação. Mesmo um relatório DxDiag não comprova desenho 3D correto, desempenho ou compatibilidade de jogos. DXVK, D3DMetal e DLSS não são instalados ou declarados implementados por essa seleção.

A prova independente é gerada por `python3 tools/build-d3d9-probe.py` como um PE Windows x64 de 2 KiB, sem copiar binários ou exigir um SDK Windows. Ela usa a ABI x64 e as interfaces D3D9 documentadas pela Microsoft para criar uma janela/dispositivo, limpar e apresentar um frame. O marcador só é emitido depois dessas chamadas; códigos 10 a 14 identificam falha em janela, Direct3DCreate9, dispositivo, limpeza ou apresentação.

O [registro real](../evidence/runtime-graphics-frame.json) observou saída zero e o marcador nos backends OpenGL e Vulkan no M1 Pro. Isso é um caso básico de API, sem comparação de pixels ou benchmark. O [DxDiag anterior](../evidence/runtime-graphics-dxdiag.json) atingiu o limite nos dois casos e foi cancelado sem XML; seus erros e avisos de bibliotecas MoltenVK distintas continuam preservados. Não se deduziu que substituir uma dessas bibliotecas seja seguro.
