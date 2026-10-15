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
| Fev e mar/2020 do VRA estão corrompidos | Todas as linhas trazem o texto `Microsoft.SqlServer.Dts.Pipeline.BlobColumn` no lugar dos horários. A versão descontinuada do histórico de voos tem os dois meses legíveis, em outro formato. O projeto deixa os dois meses de fora |
| A base estatística tem duas publicações | Zips mensais (passariam de 22 GB descompactados nos 92 meses) e um CSV acumulado de 360 MB com os mesmos números agregados por mês |
| O gov.br recusa o User-Agent padrão do Python | A página do VRA devolve 403 para `Python-urllib`. Com um User-Agent que identifica o projeto, devolve 200 |
| VRA e lista de aeródromos não começam pelo cabeçalho | A primeira linha é `Atualizado em: AAAA-MM-DD` |

## O que é um mercado

A concentração (HHI) e o número de concorrentes são medidos por mercado, e o
resultado depende de como o mercado é definido. Aqui, **mercado é um par de
cidades, sem direção**.

**Par de cidades, não de aeroportos.** Quem vai de São Paulo ao Rio escolhe
entre Congonhas, Guarulhos e Viracopos de um lado, e entre Santos Dumont e
Galeão do outro. Em ago/2026, essa viagem somou 619.821 passageiros pagos,
espalhados por seis pares de aeroportos; o maior deles, Congonhas–Santos
Dumont, ficou com 54%. Tratar cada par como um mercado partiria um mercado
só em seis e faria uma empresa parecer sozinha numa rota em que disputa o
mesmo passageiro com quem voa do aeroporto ao lado.

Os aeroportos de uma mesma cidade seguem os códigos de cidade da IATA: SAO,
RIO e BHZ, na tabela [`dados/referencia/mercados.csv`](dados/referencia/mercados.csv).
Qualquer outro aeroporto é o próprio mercado.

**Sem direção.** São Paulo → Rio e Rio → São Paulo são o mesmo mercado. Em
ago/2026, os dois sentidos tiveram quase o mesmo número de passageiros
(311.583 e 308.238). Nos 262 mercados com mais de mil passageiros naquele mês,
a diferença mediana entre ida e volta foi de 2,8%. Separar os sentidos
dobraria o número de mercados sem acrescentar informação.

**Escolhas que podem ser discutidas:**

- Viracopos fica em Campinas e é o aeroporto de quem mora lá. Entra em SAO
  porque a IATA o põe lá; tirá-lo é um teste de sensibilidade possível.
- Voo entre dois aeroportos do mesmo mercado (Guarulhos–Viracopos, por
  exemplo) não forma mercado e fica de fora.
- Jacarepaguá e Campo de Marte não estão nos grupos da IATA e continuam como
  mercados próprios.
- A tarifa é registrada pela viagem do passageiro, e o passageiro da base
  estatística, por voo. Um mesmo mercado mede as duas coisas de jeitos
  diferentes, como explica o [`DICIONARIO.md`](DICIONARIO.md).

## Estrutura

- `coletar.py`: coletor das bases da ANAC, com os testes em `teste_coletar.py`.
- `construir.py`: constrói o banco DuckDB rodando os `.sql` em ordem e depois
  os testes, com os testes do executor em `teste_construir.py`.
- `sql/`: as transformações, em SQL. `00_brutos.sql` lê os arquivos como
  texto, os `1x_stg_*.sql` padronizam cada base, e `sql/testes/` tem os
  testes de qualidade: cada um é uma consulta que devolve zero linhas quando
  está tudo certo.
- `dados/brutos/`: arquivos originais baixados; não são versionados.
- `dados/manifesto.csv` e `dados/cobertura.csv`: o que cada coleta baixou e
  encontrou.
- `dados/referencia/`: tabelas auxiliares mantidas pelo projeto.
- `dados/marts/`: conjuntos analíticos derivados, versionados no Git.
- `notebooks/`: validação e análises.
- `graficos/`: gráficos e materiais visuais.
- `powerbi/`: projeto do painel.
- `fixtures/`: amostras locais utilizadas nos testes.
- `visual.py`: padrão visual compartilhado pelos gráficos.
- `DICIONARIO.md`: o que é cada base, conferido nos dados, e o que ainda não
  se sabe sobre elas.

## Etapas

- [x] Etapa 0 — Fundação
- [x] Etapa 1 — Conhecer as bases antes do código
- [x] Etapa 2 — Coletor
- [x] Etapa 3 — Do bruto ao staging, em SQL
- [x] Etapa 4 — Validar a base
- [ ] Etapa 5 — Modelo estrela
- [ ] Etapa 6 — Concorrência e preço
- [ ] Etapa 7 — Comparar o comparável
- [ ] Etapa 8 — A fusão que não aconteceu
- [ ] Etapa 9 — Pontualidade
- [ ] Etapa 10 — Power BI
- [ ] Etapa 11 — Escrita final
- [ ] Etapa 12 — Deixar vivo (opcional)

## Como reproduzir

### Coletar os dados

Só biblioteca padrão do Python 3, sem instalar nada:

```bash
git clone https://github.com/ivadivad/voos-em-numeros.git
cd voos-em-numeros
python coletar.py todas                   # as quatro bases, de jan/2019 até o último mês publicado
python coletar.py tarifas --desde 202601  # uma base só, a partir de um mês
python coletar.py --listar                # as bases e de onde vem cada uma
python coletar.py todas --revisar         # baixa de novo o que já existe, pra achar arquivo revisado
```

Os arquivos vão para `dados/brutos/<base>/`, fora do git. São 2,8 GB:
tarifas 1,42 GB, VRA 1,07 GB, o acumulado da base estatística 0,36 GB e as
listas de aeródromos 1 MB. A primeira coleta completa, em 13/10/2026, levou
22 minutos. Rodar de novo só baixa o que falta. Os meses já baixados são pulados, e só os
arquivos sem mês (o acumulado da base estatística e as listas de
aeródromos) vêm de novo a cada rodada.

Dois arquivos da coleta ficam no git:

- `dados/manifesto.csv`: tamanho, sha256, data e URL de cada versão de cada
  arquivo baixado. Um sha256 novo num arquivo que já estava lá é revisão da
  ANAC, e as duas versões ficam registradas.
- `dados/cobertura.csv`: a situação de cada mês na última coleta que passou
  por ele (`ok`, `vazio`, `erro_403`, `erro_404`, `erro_5xx` ou
  `falha_rede`).

O coletor sai com código 1 se alguma coisa falhou. Um 404 depois do último
mês publicado não conta, porque é o mês que ainda não saiu; um 404 no meio
da série conta.

### Construir as tabelas

Precisa das dependências do `requirements.txt`, com as versões fixadas:

```bash
pip install -r requirements.txt
python construir.py
```

O `construir.py` apaga o `voos.duckdb` e o constrói do zero a partir de
`dados/brutos/`: roda os `.sql` de `sql/` em ordem alfabética, mostrando o
tempo de cada um, e depois cada teste de `sql/testes/`. Em 14/10/2026,
levou uns 30 segundos e gerou um banco de 467 MB, fora do git. Sai com código 1
se um `.sql` falhou ou se um teste devolveu linhas, e nesse caso mostra as
primeiras linhas problemáticas; o banco fica como estava, pra ser aberto e
investigado.

Os marts, os conjuntos prontos pra análise, saem da mesma construção, em
`dados/marts/`, e esses ficam no git: são pequenos, e os notebooks os leem
pela URL do GitHub, sem precisar rodar a coleta. Rodar de novo sem dado novo
grava o mesmo arquivo, byte a byte, pra não aparecer mudança falsa no git.

### Rodar os testes

```bash
python teste_coletar.py    # só biblioteca padrão, sem rede
python teste_construir.py  # precisa de duckdb; não precisa dos brutos
python teste_visual.py     # precisa de matplotlib
```
