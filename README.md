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

Todas as bases são abertas e publicadas pela ANAC.

| Base | Conteúdo | Fonte |
|---|---|---|
| Tarifas aéreas domésticas | Tarifas vendidas por companhia, origem, destino e mês | [Arquivos mensais CSV](https://sas.anac.gov.br/sas/tarifadomestica/AAAA/AAAAMM.csv) |
| Voo Regular Ativo (VRA) | Voos regulares, horários previstos e realizados e cancelamentos | [Página do VRA](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/voo-regular-ativo-vra) |
| Dados estatísticos | Passageiros, assentos e informações de etapas de voo | [Envio de informações](https://www.gov.br/anac/pt-br/assuntos/regulados/empresas-aereas/Instrucoes-para-a-elaboracao-e-apresentacao-das-demonstracoes-contabeis/envio-de-informacoes) |
| Aeródromos | Identificação, localização e coordenadas dos aeródromos públicos | [Dados abertos de aeródromos](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/aerodromos) |

Os formatos, o grão e a disponibilidade de cada base serão confirmados a
partir de amostras reais na etapa 1, antes da implementação do coletor.

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
