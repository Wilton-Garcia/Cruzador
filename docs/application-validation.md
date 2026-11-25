# Validação selecionada de aplicativos Windows

Além do 7-Zip instalado por MSI e receita, o teste nativo pode executar Plink 0.85 x86/x64 e SQLite 3.54.1 x64. As entradas são fixadas em `config/additional-validation-apps.json`, a partir dos [checksums oficiais do PuTTY](https://the.earth.li/~sgtatham/putty/0.85/sha256sums) e da [página oficial do SQLite](https://www.sqlite.org/download.html). Os hashes identificam as entradas; nenhuma validação de assinatura GPG é alegada.

```sh
python3 scripts/prepare-validation-assets.py --additional-apps
swift test --jobs 4
python3 scripts/native-smoke.py --runtime .local/Runtime-11.21 --installer-msi .local/downloads/7z2606-x64.msi --recipes config/recipes.json --apps .local/additional-apps --timeout 300
```

Os executáveis não entram no Git nem no aplicativo distribuído. O preparador verifica tamanho e SHA-256 do arquivo baixado, extrai apenas o membro SQLite nomeado e verifica seu hash. O cenário Swift verifica novamente o executável antes da execução, lê sua arquitetura PE pelo parser do produto e usa `EngineCommands`/`CommandRunner`, como a interface.

Plink é executado com `-V` nas duas arquiteturas. SQLite recebe argumentos separados para criar uma tabela, inserir um marcador e ler o banco numa segunda execução, incluindo `PRAGMA integrity_check`. Os relatórios incluem argumentos, resultados, marcadores e hashes dos logs. O supervisor exige os quatro casos e a integridade do SQLite quando `--apps` é escolhido; um callback de término isolado não basta.

Esses testes são locais e não estabelecem conexões SSH, autenticação, transferência remota, todas as funções SQL, desempenho, interface gráfica ou equivalência geral com CrossOver. O prefixo e os logs são retidos para diagnóstico. A espera do servidor se limita aos prefixes selecionados; não é um censo de todos os helpers desacoplados.
