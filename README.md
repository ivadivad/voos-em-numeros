# Voos em números

Projeto de análise do mercado doméstico de aviação no Brasil com dados abertos
da ANAC. O objetivo é investigar a relação entre concorrência, tarifas aéreas e
pontualidade, construindo uma base reproduzível com Python, SQL, DuckDB e Power
BI.

**Status:** em desenvolvimento.

## Estrutura

- `sql/`: transformações e testes de dados em SQL.
- `dados/referencia/`: tabelas auxiliares mantidas pelo projeto.
- `dados/marts/`: conjuntos analíticos derivados, versionados no Git.
- `notebooks/`: validação e análises.
- `graficos/`: gráficos e materiais visuais.
- `powerbi/`: projeto do painel.
- `fixtures/`: amostras locais utilizadas nos testes.

Os arquivos brutos baixados da ANAC ficam em `dados/brutos/` e não são
versionados.
