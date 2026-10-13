# Voos em números

Análise do mercado doméstico de aviação no Brasil com dados abertos da Agência
Nacional de Aviação Civil (ANAC). O projeto investiga a relação entre
concorrência, tarifas aéreas e pontualidade, com dados reproduzíveis,
transformações em SQL e um painel em Power BI.

> **Em desenvolvimento.** As perguntas estão definidas antes da análise dos
> dados; ainda não há resultados.

## A pergunta

**A falta de concorrência deixa a passagem aérea mais cara no Brasil?**

1. Em mercados com menos companhias, a tarifa por quilômetro é mais alta,
   comparando distâncias parecidas?
2. Se a fusão Azul + GOL tivesse acontecido, quantos mercados passariam dos
   limites de concentração do CADE, e quantas pessoas voariam neles?
3. Pagar mais caro compra pontualidade?

O período de análise começa em janeiro de 2019 e vai até o último mês publicado
pelas fontes. O projeto usa tarifas domésticas registradas pela ANAC, vendidas
ao público adulto em geral. Milhas, pacotes e tarifas corporativas ficam de
fora.

## Fontes

Todas as bases são abertas e publicadas pela ANAC. O que cada uma traz, linha
a linha, está no [`DICIONARIO.md`](DICIONARIO.md).

| Base | Conteúdo | Fonte |
|---|---|---|
| Tarifas aéreas domésticas | Valores de tarifa vendidos por empresa, origem, destino e mês da venda, com os assentos vendidos a cada valor | [Página do conjunto](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/tarifas-aereas-domesticas). Arquivos em `https://sas.anac.gov.br/sas/tarifadomestica/AAAA/AAAAMM.csv` |
| Voo Regular Ativo (VRA) | Etapas de voo, com horários previstos e realizados e cancelamentos | [Página do conjunto](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/voo-regular-ativo-vra) |
| Dados estatísticos | Passageiros, assentos, decolagens e distância por empresa, par de aeródromos e mês | [Página do conjunto](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/dados-estatisticos-do-transporte-aereo) |
| Aeródromos públicos | Código, cidade atendida e coordenadas de cada aeródromo | [Página do conjunto](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/aerodromos/aerodromos-publicos/lista-de-aerodromos-publicos) |

### Notas sobre as fontes

Conferido em 13/10/2026.

| Base | Último mês publicado | Prazo documentado | O que se observou |
|---|---|---|---|
| Tarifas | ago/2026 | As empresas registram as tarifas "até o dia 10 (dez) do mês subsequente" ([Resolução ANAC nº 780/2025](https://www.anac.gov.br/assuntos/legislacao/legislacao-1/resolucoes/2025/resolucao-780), em vigor desde 01/02/2026). Não há prazo para a ANAC publicar | De fev a ago/2026, o arquivo apareceu de 15 a 28 dias depois do fim do mês (data de modificação de cada um). O de jan/2026 saiu junto com o de fev, em 20/03 |
| VRA | ago/2026. A pasta de set/2026 já existe, vazia | Os metadados dizem só "Mensal" | As pastas de mai, jun e jul/2026 têm data do dia 28 do mês seguinte, sempre às 04h09 |
| Dados estatísticos | ago/2026 | As empresas enviam os dados "até o dia 10 do mês subsequente ao de referência" ([metadados](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/dados-estatisticos-do-transporte-aereo/48-dados-estatisticos-do-transporte-aereo)) | O zip de ago/2026 foi gerado em 14/09/2026. O arquivo acumulado é regerado com frequência: a data dele era a do dia da conferência |
| Aeródromos | Lista de 01/10/2026 | "Aproximadamente a cada 40 dias" ([metadados](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/aerodromos/aerodromos-publicos/lista-de-aerodromos-publicos/metadados-do-conjunto-de-dados-lista-de-aerodromos-publicos-v2)) | É um retrato da lista atual, sem versão por mês |

Comportamentos que custaram tempo para descobrir, registrados para quem for
usar as mesmas bases:

| Comportamento | Detalhe |
|---|---|
| A ANAC substitui arquivos antigos | Meses de tarifas de 2023 e de 2024 têm data de mar/2026; quase todo o VRA, de 07/10/2026. É por isso que o coletor da etapa 2 registra o sha256 de cada arquivo baixado |
| O formato das tarifas muda de um mês para outro | Cinco versões de cabeçalho, vírgula ou ponto decimal, fim de linha do Windows ou do Linux. Só a ordem das sete colunas é constante |
| Mai/2026 das tarifas tem outro nome | `202605.csv` dá 404; o arquivo publicado é `202605 (1).CSV` |
| Fev e mar/2020 do VRA estão corrompidos | Os horários trazem o texto `Microsoft.SqlServer.Dts.Pipeline.BlobColumn`. A versão descontinuada do histórico de voos tem os dois meses legíveis, em outro formato |
| A base estatística tem duas publicações | Zips mensais (passariam de 22 GB descompactados nos 92 meses) e um CSV acumulado de 360 MB com os mesmos números agregados por mês |
| O gov.br recusa o User-Agent padrão do Python | A página do VRA devolve 403 para `Python-urllib`. Com um User-Agent que identifica o projeto, devolve 200 |
| VRA e lista de aeródromos não começam pelo cabeçalho | A primeira linha é `Atualizado em: AAAA-MM-DD` |

## Estrutura

- `coletar.py`: coletor das bases da ANAC (a implementar).
- `construir.py`: executor das transformações SQL em DuckDB (a implementar).
- `sql/`: transformações e testes de qualidade em SQL.
- `dados/brutos/`: arquivos originais baixados; não são versionados.
- `dados/referencia/`: tabelas auxiliares mantidas pelo projeto.
- `dados/marts/`: conjuntos analíticos derivados, versionados no Git.
- `notebooks/`: validação e análises.
- `graficos/`: gráficos e materiais visuais.
- `powerbi/`: projeto do painel.
- `fixtures/`: amostras locais utilizadas nos testes.
- `visual.py`: padrão visual compartilhado pelos gráficos.
- `DICIONARIO.md`: documentação das bases e das transformações (a criar).

## Etapas

- [x] Etapa 0 — Fundação
- [ ] Etapa 1 — Conhecer as bases antes do código
- [ ] Etapa 2 — Coletor
- [ ] Etapa 3 — Do bruto ao staging, em SQL
- [ ] Etapa 4 — Validar a base
- [ ] Etapa 5 — Modelo estrela
- [ ] Etapa 6 — Concorrência e preço
- [ ] Etapa 7 — Comparar o comparável
- [ ] Etapa 8 — A fusão que não aconteceu
- [ ] Etapa 9 — Pontualidade
- [ ] Etapa 10 — Power BI
- [ ] Etapa 11 — Escrita final
- [ ] Etapa 12 — Deixar vivo (opcional)

## Como reproduzir

Os comandos de coleta e construção serão documentados quando essas etapas
forem implementadas.
