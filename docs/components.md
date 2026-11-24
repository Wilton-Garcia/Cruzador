# Componentes do CrossOver instalado

Catálogo derivado dos fatos de diretório decodificados pelo REA. As categorias descrevem a localização e o papel provável de distribuição; não estabelecem execução nem equivalência de implementação.

| Categoria | Entradas |
| --- | ---: |
| application-perl | 72 |
| application-python | 50 |
| bottle-templates | 39 |
| command-tools | 36 |
| command-tools-alias | 1 |
| compatibility-data | 25 |
| configuration | 1 |
| documentation-and-notices | 3 |
| graphics-backends | 61 |
| interface-and-resources | 1455 |
| localization | 123 |
| mono-runtime | 3374 |
| native-application | 1 |
| native-support-libraries | 118 |
| other-or-unclassified | 293 |
| python-runtime | 616 |
| updater-framework | 178 |
| wine-runtime | 1667 |

Total: 8113 entradas retidas. Evidência `ev_a9378e60a0e1831eb09d542597977f79e8e18545aeea4f68398ca6e0c1e8a708`.

O link `Contents/SharedSupport/CrossOver/bin` aponta para `CrossOver-Hosted Application`, observado com `readlink`. Os caminhos lógicos usados pelo lançador e o diretório físico não são duas instalações. O catálogo mantém links como entradas e não os percorre.

As bibliotecas Wine ficam em `lib/wine`; DXVK e DXMT têm diretórios próprios em `lib`. A área `lib64/apple_gptk` e bibliotecas de suporte são inventariadas separadamente. Mono está em `share/wine/mono`. Essas localizações não demonstram quais componentes cada aplicativo carrega.

A sondagem não apresentou problemas de leitura nos arquivos selecionados, mas a cobertura permanece parcial: links não seguidos e conteúdo não lido continuam desconhecidos. Não foi feito hash integral de todos os arquivos. A observação anterior tinha contagem diferente; são fotografias distintas do diretório, sem afirmação de atomicidade ou equivalência de conteúdo.

[Catálogo completo](../evidence/component-catalog.json) e [evidência original](../evidence/component-inventory.evidence.json). Para verificar a projeção: `python3 scripts/build-component-catalog.py --check`.
