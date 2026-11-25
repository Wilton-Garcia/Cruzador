# Descoberta de aplicativos

**Buscar instalados** observa a bottle selecionada sem executar programas. O resultado separa registros de software e candidatos executáveis. O usuário escolhe os arquivos que deseja transformar em atalhos; nomes de registro, ícones ou a presença de um arquivo não são tratados como prova de que ele seja o programa principal ou funcione no Wine.

A busca lê `system.reg` e `user.reg`, selecionando as chaves diretas de desinstalação de 32/64 bits, e percorre `drive_c/Program Files` e `drive_c/Program Files (x86)`. Não segue links de diretórios. Erros de leitura, formatos desconhecidos e arquivos não reconhecidos geram avisos; raízes comprovadamente ausentes são registradas separadamente. Instalações por usuário, executáveis portáteis fora dessas pastas, unidades externas e arquivos `.lnk` não são enumerados por esta busca.

`WineRegistryDocument` interpreta o formato 2 no limite de leitura, incluindo escapes Unicode, aspas e barras, e conserva valores de tipos não suportados ou malformados com sua origem. Valores duplicados permanecem ambíguos. O formato é descrito no [leitor/gravador de registro do Wine](https://github.com/wine-mirror/wine/blob/wine-11.21/server/registry.c) e os escapes em [seu suporte Unicode](https://github.com/wine-mirror/wine/blob/wine-11.21/server/unicode.c). Consumidores usam os campos interpretados; não voltam a interpretar linhas do registro.

Cada registro observado inclui arquivo, chave, linha e digest dos bytes examinados. O local Windows declarado e o local resolvido dentro do prefixo permanecem separados. Variáveis de uma string expandida não são substituídas pelo ambiente do macOS. Diretórios Windows não resolvidos continuam desconhecidos; não são classificados como inexistentes.

A inspeção PE é compartilhada com os instaladores por `WindowsFileInspection`. Antes de cadastrar um candidato, o Cruzador confere novamente arquivo, tamanho, data e pertencimento ao prefixo. O mesmo executável sem argumentos não é cadastrado duas vezes. Essa conferência de metadados não autentica o conteúdo nem cria um snapshot atômico do disco.

O [cenário real registrado](../evidence/runtime-discovery.json) encontrou o 7-Zip instalado pelos testes anteriores, com três registros de software e dez candidatos PE nas raízes examinadas. Os testes também verificam valores Unicode, campos malformados, duplicados, links não seguidos, raiz inválida e arquivo alterado entre busca e seleção. Esses resultados não demonstram cobertura integral dos launchers ou atalhos do CrossOver.
