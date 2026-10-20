# Voos em números

Análise do mercado doméstico de aviação no Brasil com dados abertos da Agência
Nacional de Aviação Civil (ANAC). O projeto investiga a relação entre
concorrência, tarifas aéreas e pontualidade, com dados reproduzíveis,
transformações em SQL e um painel em Power BI.

> **Em desenvolvimento: as etapas 0 a 8 estão concluídas** (ver
> [Etapas](#etapas)). As perguntas foram escritas antes de abrir os dados.
> Já há resultados nos notebooks: a [validação da
> base](notebooks/01-validacao.ipynb), a [comparação crua entre concorrência
> e preço](notebooks/02-concorrencia-e-preco.ipynb), a mesma comparação
> [entre mercados de distância parecida](notebooks/03-comparar-o-comparavel.ipynb)
> e a [simulação da fusão Azul + GOL](notebooks/04-fusao.ipynb). A
> pontualidade (pergunta 3) e o painel ainda não começaram, e as respostas
> às três perguntas entram aqui na etapa 11.

## A pergunta

**A falta de concorrência deixa a passagem aérea mais cara no Brasil?**

1. Em mercados com menos companhias, a tarifa por quilômetro é mais alta,
   comparando distâncias parecidas?
2. Se a fusão Azul + GOL tivesse acontecido, quantos mercados passariam dos
   limites de concentração do CADE, e quantas pessoas voariam neles?
3. Pagar mais caro compra pontualidade?

O período de análise começa em janeiro de 2019 e vai até o último mês publicado
pelas fontes. O projeto usa as tarifas domésticas registradas pela ANAC, que,
pelos [metadados](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/tarifas-aereas-domesticas/46-tarifas-aereas-domesticas),
"abrangem todas as passagens vendidas ao “público adulto em geral”,
excluindo aquelas adquiridas com descontos restritos a grupos específicos,
programas de milhagem, entre outras condições".

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
a ida e a volta diferiram, na mediana, 5,6% em relação à média dos dois
sentidos. Separar os sentidos dobraria o número de mercados sem acrescentar
informação.

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

## O modelo

As três bases viram um modelo estrela no DuckDB: um fato por base e as
dimensões que os três compartilham. As dimensões também vão pra
`dados/marts/dim_*.parquet`, pro painel usar as mesmas tabelas que o SQL.
Os fatos ficam só no banco, grandes demais pro Git (o das tarifas tem 34
milhões de linhas), e os marts das próximas etapas saem deles.

```mermaid
erDiagram
    dim_calendario ||--o{ fato_tarifa : mes
    dim_calendario ||--o{ fato_voo : mes
    dim_calendario ||--o{ fato_oferta : mes
    dim_grupo ||--o{ fato_tarifa : grupo
    dim_grupo ||--o{ fato_voo : grupo
    dim_grupo ||--o{ fato_oferta : grupo
    dim_mercado ||--o{ fato_tarifa : mercado
    dim_mercado ||--o{ fato_voo : mercado
    dim_mercado ||--o{ fato_oferta : mercado
    dim_empresa ||--o{ fato_voo : empresa
    dim_aeroporto ||--o{ fato_voo : origem
    dim_aeroporto ||--o{ fato_voo : destino
    dim_empresa ||--o{ empresa_grupo : empresa
    dim_grupo ||--o{ empresa_grupo : grupo

    fato_tarifa {
        date mes FK
        varchar grupo FK
        varchar mercado FK
        decimal tarifa
        bigint assentos
    }
    fato_voo {
        date mes FK
        varchar empresa FK
        varchar grupo FK
        varchar mercado FK
        varchar origem FK
        varchar destino FK
        varchar voo
        timestamp partida_prevista
        timestamp partida_real
        timestamp chegada_prevista
        timestamp chegada_real
        varchar situacao
        boolean cancelado
        integer atraso_chegada_min
    }
    fato_oferta {
        date mes FK
        varchar grupo FK
        varchar mercado FK
        varchar grupo_de_voo
        bigint passageiros_pagos
        bigint passageiros_gratis
        bigint assentos
        bigint decolagens
        bigint distancia_voada_km
        bigint ask
        bigint rpk
    }
    dim_calendario {
        date mes PK
        bigint ano
        bigint trimestre
        bigint numero_mes
        varchar nome_mes
        varchar mes_abreviado
        varchar rotulo
    }
    dim_grupo {
        varchar grupo PK
        varchar nome_grupo
        varchar grupo_simulado
    }
    dim_empresa {
        varchar empresa PK
        varchar nome_empresa
        varchar nome_anac
    }
    empresa_grupo {
        varchar empresa FK
        varchar grupo FK
        date desde
        date ate
        varchar fonte
    }
    dim_mercado {
        varchar mercado PK
        varchar cidade_a
        varchar nome_cidade_a
        varchar cidade_b
        varchar nome_cidade_b
        varchar nome
        decimal distancia_km
        varchar distancia_fonte
    }
    dim_aeroporto {
        varchar icao PK
        varchar nome
        varchar municipio
        varchar uf
        double latitude
        double longitude
        varchar cidade
        varchar nome_cidade
        varchar cadastro
    }
```

| Tabela | Uma linha é |
|---|---|
| `fato_tarifa` | um grupo, um mercado, um mês da venda e um valor de tarifa, com os assentos vendidos por esse valor |
| `fato_voo` | um voo do VRA, com os horários, a situação e o atraso na chegada |
| `fato_oferta` | um grupo, um mercado, um mês e um grupo de voo (regular, não regular ou improdutivo), com passageiros, assentos, decolagens, ASK e RPK |
| `dim_calendario` | um mês, de jan/2019 a ago/2026 |
| `dim_grupo` | um grupo econômico (21), com o grupo da fusão simulada: Azul e GOL viram um só |
| `dim_empresa` | uma empresa das três bases (24) |
| `empresa_grupo` | uma empresa num período, com o grupo a que ela pertencia nele |
| `dim_mercado` | um par de cidades sem direção, com a distância (8.983) |
| `dim_aeroporto` | um aeroporto das três bases, com a cidade do mercado (306) |

Os números são da coleta de 13/10/2026. Três decisões pesam no resto da
análise:

**O grupo econômico muda no tempo.** A concentração é medida entre donos,
não entre marcas, e duas empresas trocaram de dono dentro do período: a
TwoFlex, hoje Azul Conecta, é da Azul a partir de jun/2020, e a MAP, da
VoePass a partir de set/2019. Antes disso, cada uma é um grupo próprio. Por
isso o grupo não é uma coluna da `dim_empresa`: a `empresa_grupo` guarda os
períodos, e cada fato traz o grupo da empresa no mês da linha. A ligação de
cada empresa, com a fonte, está em
[`dados/referencia/grupos.csv`](dados/referencia/grupos.csv).

**A distância de um mercado** é a média das distâncias em linha reta entre
os aeroportos das duas cidades, ponderada pelos assentos vendidos no
período. Rio–São Paulo fica com 365,9 km, entre os 336,8 km de
Guarulhos–Galeão e os 406,8 km de Viracopos–Santos Dumont. Com esse peso,
a tarifa por quilômetro calculada pelo mercado dá, no período, o mesmo
R$ 0,4357/km da conta feita par de aeroportos a par. Os 18 aeroportos que
não estão nas listas de aeródromos da ANAC não têm coordenada: neles vale a
distância que a ANAC publica para voo direto, e 428 mercados, com 0,06% dos
assentos vendidos, ficam sem distância.

**O que fica de fora** é o par de aeroportos da mesma cidade, que não forma
mercado: 14 assentos das tarifas, 823 voos do VRA e 428.410 passageiros
pagos da base estatística, 94,5% deles em voos do grupo improdutivo que
voltaram ao aeroporto de onde saíram. Os testes de cada fato conferem que
ele, somado ao que ficou de fora, fecha exatamente com a staging.

## A fusão Azul + GOL

A segunda pergunta é sobre uma fusão que chegou a ser negociada e não
aconteceu. As datas, cada uma com a fonte:

| Data | O que aconteceu | Fonte |
|---|---|---|
| mai/2024 | Azul e GOL assinam um acordo de codeshare, a venda de assentos uma no voo da outra | [InfoMoney, 26/09/2025](https://www.infomoney.com.br/mercados/gol-desiste-de-processo-de-fusao-com-a-azul/): "as empresas também confirmaram a rescisão do acordo de codeshare, assinado em maio de 2024 para integrar suas malhas aéreas no Brasil" |
| 15/01/2025 | A Abra, controladora da GOL, e a Azul assinam um memorando de entendimentos não vinculante | [Fato relevante da GOL de 15/01/2025](https://static.poder360.com.br/2025/01/fato-relevante-azul-gol.pdf), cópia no Poder360: "a Abra e a Azul S.A. ("Azul") assinaram, na presente data, Memorandum of Understanding (Memorando de Entendimentos) (“MoU”) não vinculante com o objetivo de explorar uma combinação de negócios no Brasil" |
| 25/09/2025 | A Abra encerra as negociações, e as duas rescindem o codeshare | [Poder360, 26/09/2025](https://www.poder360.com.br/poder-economia/gol-e-azul-encerram-negociacoes-de-fusao/): "O grupo Abra, controlador da GOL, anunciou na 5ª feira (25.set.2025) que encerrou as negociações para uma fusão com a Azul." |

**Como a fusão é simulada.** A `dim_grupo` tem um grupo simulado em que
Azul e GOL são um só, e o `sql/60_mart_fusao.sql` recalcula a
concentração de cada mercado com ele, em duas janelas de 12 meses: 2024, o
mercado que a fusão encontraria, e os 12 meses mais recentes. A leitura é a
da seção 2.4.2 do [guia de concentração horizontal do
CADE](https://cdn.cade.gov.br/Portal/centrais-de-conteudo/publicacoes/guias-do-CADE/guia-para-analise-de-atos-de-concentracao-horizontal.pdf),
e o projeto a usa como triagem, não como veredito: o próprio guia diz que
"A 'regra do HHI', como indicativa de nexo causal é uma suposição inicial,
sensível a outros argumentos". E a simulação é estática: soma as duas
companhias no mercado de cada janela, sem supor que alguém reaja, entre ou
saia. O resultado está no notebook `04-fusao`.

## Pontualidade

A terceira pergunta usa o Voo Regular Ativo (VRA) da ANAC: cada voo
doméstico regular de passageiros previsto, com os horários previstos e os
realizados. **Atraso é na chegada, acima de 15 minutos**, sobre os voos
realizados com os dois horários; acima de 30 e de 60 minutos entram como
sensibilidade. O cancelamento é sobre os realizados mais os cancelados, e
os 1.158 voos com situação `NÃO INFORMADO` (de ago/2020 a out/2023) ficam
fora da conta principal. A hora é a da partida prevista, no horário de
Brasília, que é o do VRA.

**A ordem dos grupos muda com o corte.** Em quatro dos oito anos da base
(2020, 2023, 2025 e 2026), quem atrasa mais ou menos depende de onde fica a
linha: em 2025, a LATAM é a que mais atrasa acima de 15 minutos, e a Azul,
acima de 30 e de 60. Por isso o projeto mostra os três cortes, e não um
ranking só. O detalhe está no notebook `05-pontualidade`.

## Estrutura

- `coletar.py`: coletor das bases da ANAC, com os testes em `teste_coletar.py`.
- `construir.py`: constrói o banco DuckDB rodando os `.sql` em ordem e depois
  os testes, com os testes do executor em `teste_construir.py`.
- `sql/`: as transformações, em SQL. `00_brutos.sql` lê os arquivos como
  texto, os `1x_*.sql` padronizam cada base e definem a distância entre
  aeródromos, os `2x_dim_*.sql` e `3x_fato_*.sql` montam o modelo estrela,
  os `40_mart_*.sql` em diante gravam os marts, e `sql/testes/` tem os
  testes de qualidade: cada um é uma consulta que devolve zero linhas quando
  está tudo certo.
- `dados/brutos/`: arquivos originais baixados; não são versionados.
- `dados/manifesto.csv` e `dados/cobertura.csv`: o que cada coleta baixou e
  encontrou.
- `dados/referencia/`: tabelas auxiliares mantidas pelo projeto:
  `mercados.csv` (os aeroportos de uma mesma cidade) e `grupos.csv` (o
  grupo econômico de cada empresa, com a fonte).
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
- [x] Etapa 5 — Modelo estrela
- [x] Etapa 6 — Concorrência e preço
- [x] Etapa 7 — Comparar o comparável
- [x] Etapa 8 — A fusão que não aconteceu
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
tempo de cada um, e depois cada teste de `sql/testes/`. Em 16/10/2026, com
o modelo estrela da etapa 5, levou uns 60 segundos com a máquina livre (58
e 59 s em duas rodadas seguidas), e de 96 a 126 segundos com um programa
pesado aberto, e gerou um banco de 919 MB, fora do git. O DuckDB fica limitado a 2 GB de memória, e o que não
cabe vai pro disco, em `voos.duckdb.tmp/`: sem o limite, a agregação das
tarifas falhava numa máquina com outros programas abertos. A construção
inteira chegou a 2,4 GB de memória comprometida, e precisa desse tanto
livre: com menos, para com "Out of Memory Error". Sai com código 1 se um
`.sql` falhou ou se um teste devolveu linhas, e nesse caso mostra as
primeiras linhas problemáticas; o banco fica como estava, pra ser aberto e
investigado.

Os marts, os conjuntos prontos pra análise, e as dimensões do modelo saem
da mesma construção, em `dados/marts/`, e esses ficam no git: são pequenos
(3,48 MB juntos em 20/10/2026; o maior, o mart de mercado por mês, tem
1,97 MB), e os notebooks os leem pela URL do GitHub, sem precisar
rodar a coleta. Rodar de novo sem dado novo grava o mesmo arquivo, byte a
byte, pra não aparecer mudança falsa no git.

### Rodar os testes

```bash
python teste_coletar.py    # só biblioteca padrão, sem rede
python teste_construir.py  # precisa de duckdb; não precisa dos brutos
python teste_visual.py     # precisa de matplotlib
```
