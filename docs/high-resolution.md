# Alta resolução Retina

Em **Alta resolução**, escolha ativar, desativar ou restaurar o padrão. O fluxo integrado exige o Wine 11.21 incluído e uma bottle pronta. Feche os programas antes de aplicar: o Cruzador aguarda o servidor encerrar, preserva `user.reg` em `Backups/retina-UUID.reg`, usa o `reg.exe` da bottle e aguarda a gravação persistir.

A opção é `HKCU\Software\Wine\Mac Driver\RetinaMode`, conforme o [driver macOS do Wine 11.21](https://github.com/wine-mirror/wine/blob/wine-11.21/dlls/winemac.drv/macdrv_main.c). O padrão remove apenas essa substituição. O registro é a fonte da escolha; não existe uma cópia concorrente da configuração no arquivo de biblioteca. A tela distingue valor salvo, padrão e valor desconhecido, inclusive registro malformado ou tipo não reconhecido.

A mudança vale para novos processos. Falha de espera não escreve no registro nem cria um backup enganoso de mudança aplicada. A confirmação exige ler novamente o valor salvo. Uma aplicação idempotente preserva os bytes do registro.

O [registro de execução](../evidence/runtime-retina.json) conserva ativação, desativação e restauração do padrão no Wine real, junto dos cenários seguintes. Esse teste confirma a configuração persistida, não qualidade de pixels, ganho de desempenho, escala idêntica em monitores diferentes ou compatibilidade de todos os aplicativos. Outros motores permanecem explicitamente não validados para essa opção.
