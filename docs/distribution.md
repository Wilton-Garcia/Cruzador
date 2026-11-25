# Instalação, atualização e distribuição

## Pacote local

O empacotador gera um DMG para instalação pelo Finder, sem alterar o aplicativo instalado nem a biblioteca:

```sh
CRUZADOR_UNIVERSAL=1 scripts/build-app.sh
python3 scripts/package-release.py --output build/releases/local-001
```

A pasta de saída deve ser nova e ficar fora do bundle. O empacotador valida a identidade do Cruzador, a assinatura local e o inventário Wine fixado; copia o aplicativo preservando seus links; cria a imagem; verifica o DMG; monta somente para leitura; confere a assinatura e o hash do executável embarcado; desmonta; e grava `release.json`. Falhas retêm a área de preparo. O registro descreve o arquivo efetivamente produzido e distingue verificação local de distribuição pública.

A imagem inclui um link para `/Applications` e [instruções de instalação e atualização](Installation.html). A atualização é manual: encerrar o aplicativo e os programas Windows, preservar cópias compatíveis e substituir o bundle pelo Finder. O aplicativo e a biblioteca em `~/Library/Application Support/Cruzador` têm ciclos separados. Não há atualizador automático ou feed remoto implementado.

O [registro local do pacote](../evidence/local-release-package.json) identifica o DMG verificado. Os binários continuam fora do Git. A cópia empacotada é uma observação de build, sem alegar todos os fluxos testados em um Mac novo.

## Distribuição assinada

O build atual usa assinatura ad hoc. Ainda faltam uma identidade válida **Developer ID Application**, notarização e avaliação do Gatekeeper em outra máquina. O Wine traz executáveis e bibliotecas nativas que precisam ser considerados na assinatura; assinar apenas o bundle externo não substitui essa validação. Não se escolhem entitlements de memória executável por suposição: será necessário verificar os requisitos do Wine selecionado sob hardened runtime e repetir os testes reais após a assinatura.

A distribuição pública também depende da revisão da correspondência de fontes e licenças das dependências do runtime. O lock registra a origem do pacote, revisão Wine e textos de licença; isso não conclui a revisão de todos os componentes de terceiros. O pacote opcional WineCX tem a mesma pendência e permanece separado do padrão.

Assinatura e notarização foram adiadas por solicitação do mantenedor. O preparo local não envia o aplicativo à Apple, publica uma release ou instala certificados. Credenciais e chaves privadas não entram no repositório.
