# Dicionário de dados

O que é cada base da ANAC usada no projeto, aberta e conferida antes de
qualquer linha de código (etapa 1). Onde uma característica foi conferida nos
dados, está dito em quantos arquivos ou linhas. Onde a fonte é a documentação
oficial, o link vai junto. Conferências feitas em 13/10/2026. No fim, os
arquivos que o projeto publica em `dados/marts/`: o que é uma linha, as
colunas e o que não se soma.

---

# Tarifas aéreas domésticas

**Fonte:** [página do conjunto](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/tarifas-aereas-domesticas)
e [metadados](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/tarifas-aereas-domesticas/46-tarifas-aereas-domesticas).
Um arquivo por mês, em `https://sas.anac.gov.br/sas/tarifadomestica/AAAA/AAAAMM.csv`.

**O que foi aberto:** os 92 arquivos de jan/2019 a ago/2026 (1,42 GB no total,
de 3,2 MB em mai/2020 a 28,8 MB em nov/2025), os primeiros 8 KB de cada um, e
dois meses inteiros: jan/2019 (418.098 linhas) e ago/2026 (818.120 linhas).

## O que é uma linha

**Um valor de tarifa vendido por uma empresa, de uma origem para um destino,
num mês, com o número de assentos vendidos por esse valor.** Nas duas amostras
completas, nenhuma combinação de empresa, origem, destino e tarifa se repete
dentro do mês, que é a chave que os metadados descrevem para os assentos
comercializados.

Três pontos dos metadados que mudam a análise:

- **O mês é o da venda, não o do voo.** Sobre os campos de ano e mês: "Indicam
  o ano e o mês em que as passagens registradas foram vendidas,
  independentemente da data do voo." Não dá pra cruzar tarifa e pontualidade
  do mesmo mês como se fossem as mesmas viagens.
- **A empresa é a que vendeu, não a que operou.** Passagem de codeshare entra
  na conta de quem vendeu.
- **Origem e destino são os do passageiro**, independentemente de escalas ou
  conexões. Passagens de ida e volta e de múltiplos destinos aparecem
  fracionadas, como passagens de uma origem e um destino.

## Colunas

Sete colunas, sempre na mesma ordem. O nome muda de arquivo para arquivo (ver
"Formato"); a tabela usa os da versão mais recente.

| Posição | Nome (versão E) | Tipo | Descrição |
|---|---|---|---|
| 1 | `nr_ano_referencia` | inteiro | Ano da venda |
| 2 | `nr_mes_referencia` | inteiro | Mês da venda, sem zero à esquerda (`8`, não `08`) |
| 3 | `sg_empresa_icao` | texto, 3 letras | Designador OACI da empresa que vendeu |
| 4 | `sg_icao_origem` | texto, 4 letras | Aeródromo de origem do passageiro, código OACI |
| 5 | `sg_icao_destino` | texto, 4 letras | Aeródromo de destino do passageiro, código OACI |
| 6 | `nr_tarifa` | decimal | Valor nominal em reais. Não inclui tarifa de embarque nem serviços opcionais |
| 7 | `nr_assentos` | inteiro | Assentos vendidos por esse valor, no mês |

## Formato: quase nada é constante entre os arquivos

| Característica | O que os 92 arquivos mostram |
|---|---|
| Separador | `;` em todos |
| Cabeçalho | Cinco versões, que se alternam sem ordem cronológica (tabela abaixo) |
| Encoding | Os dados são só ASCII (nas duas amostras completas, nenhum byte acima de 127). Acento só nos cabeçalhos: Latin-1 nas versões B e D, UTF-8 com BOM na C |
| Fim de linha | `\r\n` em 74 arquivos, `\n` em 18 |
| Aspas | Só nos 2 arquivos da versão D |
| Separador decimal | Vírgula em 80 arquivos e **ponto em 12** (out e nov/2024, mar a dez/2025). Nos trechos abertos, nenhum valor usa separador de milhar |
| Casas decimais | De 0 a 2, variando dentro do mesmo arquivo |
| Mês das linhas | Bate com o nome do arquivo nas 45.296.499 linhas dos 92 arquivos (conferido na etapa 3) |

| Versão | Cabeçalho | Arquivos |
|---|---|---|
| A | `ANO;MES;EMPRESA;ORIGEM;DESTINO;TARIFA;ASSENTOS` | 41 |
| B | `Ano de Referência;Mês de Referência;ICAO Empresa Aérea;ICAO Aeródromo Origem;ICAO Aeródromo Destino;Tarifa-N;Assentos Comercializados` | 23 |
| C | O mesmo da B, em UTF-8 com BOM | 1 (mai/2020) |
| D | O mesmo da B, entre aspas, com uma primeira coluna sem nome que numera as linhas: `"1";2021;12;"AZU";"SBKP";"SBIL";"3643,9";4` | 2 (dez/2021 e abr/2022) |
| E | `nr_ano_referencia;nr_mes_referencia;sg_empresa_icao;sg_icao_origem;sg_icao_destino;nr_tarifa;nr_assentos` | 25 |

**O que isso pede da leitura (etapa 3):** ler pela posição da coluna, nunca
pelo nome; descartar a coluna de numeração da versão D; converter a tarifa
trocando vírgula por ponto, o que serve aos dois formatos enquanto nenhum
arquivo usar separador de milhar; e contar o que não converter, em vez de
deixar sumir.

## Publicação e revisão

- **Maio/2026 tem outro nome.** `2026/202605.csv` devolve 404. Na listagem
  oficial ([DataSAS](https://sas.anac.gov.br/sas/downloads/view/frmDownload.aspx?tema=14)),
  o arquivo aparece como `202605 (1).CSV` e baixa por `2026/202605%20(1).CSV`.
  Os outros 91 meses seguem o padrão. Um coletor que só monta a URL perde esse
  mês sem erro nenhum à vista.
- **Arquivos antigos são substituídos.** A data de modificação dos arquivos de
  mai a jul/2023 e de jun a set/2024 é mar/2026; a de quase todo 2019, jan/2020.
  Os metadados avisam: "Os dados são sujeitos a revisão."
- **Os códigos de aeroporto podem mudar entre versões.** Pelos metadados, "os
  microdados são publicados com os designadores vigentes na data da
  disponibilização". Um arquivo revisado pode trazer códigos diferentes do
  original.
- **Cobertura parcial, por definição.** As tarifas são as vendidas ao "público
  adulto em geral". Ficam de fora descontos restritos a grupos, programas de
  milhagem e outras condições. Dos metadados: "O número de assentos vendidos
  registrados corresponde a cerca de 50% do movimento de passageiros pagos
  transportados."

## Valores nas duas amostras completas

| | jan/2019 | ago/2026 |
|---|---|---|
| Linhas | 418.098 | 818.120 |
| Empresas | 7 | 5 |
| Aeródromos de origem | 128 | 142 |
| Assentos vendidos | 3.496.805 | 2.637.211 |
| Tarifa mínima / máxima | R$ 40,18 / R$ 5.507,41 | R$ 75,13 / R$ 4.977,48 |
| Pares origem→destino sem o sentido inverso no mês | 448 de 6.892 | 583 de 6.151 |

Nenhuma tarifa ou quantidade de assentos zerada, negativa ou que não converta.
Os códigos de aeroporto têm sempre 4 letras e começam com `SB`, `SN`, `SW`,
`SS`, `SD` ou `SJ`; os de empresa, sempre 3 letras.

## No período inteiro (etapa 3)

A staging leu as 45.296.499 linhas dos 92 arquivos, de 11 empresas. O que as
duas amostras mostravam continua valendo: nenhuma combinação de empresa,
origem, destino, mês e tarifa se repete, e nenhum valor deixa de converter.
Duas novidades:

- **Nem todo código de aeroporto é só de letras.** `SN6L` aparece em 95
  linhas, de nov/2023 a jan/2025.
- **Tarifas nas pontas.** Vão de R$ 1,00 a R$ 13.149,90. São 377 abaixo de
  R$ 10 e 4 acima de R$ 10 mil. A validação da etapa 4 não decidiu se são
  erro de registro (nenhuma cai nos meses com comunicado da ANAC pra
  conferir), mas o peso é desprezível: 9.500 assentos, 0,004% do total.

## Como a tarifa média é calculada (etapa 4)

Conferido no notebook `01-validacao`, contra os comunicados mensais da ANAC,
o Anuário do Transporte Aéreo e a imprensa:

- **Tarifa média:** a receita (cada tarifa vezes os assentos vendidos a ela)
  dividida pelos assentos, no mês da venda, juntando todas as empresas e
  rotas. É média ponderada pelos assentos, e não média simples das tarifas.
  Bate no centavo com os comunicados de jun, jul e ago/2026 (R$ 660,54,
  R$ 703,52 e R$ 776,87) e com a tarifa de cada empresa em ago/2026.

  $$\text{tarifa média} = \frac{\sum \text{tarifa} \times \text{assentos}}{\sum \text{assentos}}$$

- **Valor real:** cada mês é levado ao preço do mês de referência pelo IPCA
  (série 433 do Banco Central), multiplicando pelo índice da referência e
  dividindo pelo índice do mês. Nos comunicados mensais, a referência é o
  próprio mês publicado, e o valor do mês sai nominal. No Anuário, é
  dezembro do ano: com essa base, 2022 dá R$ 727,01 e 2024, R$ 670,11,
  contra os R$ 727 e R$ 670 publicados.
- **Faixas de preço:** "abaixo de R$ 500", nos comunicados, inclui os
  R$ 500. Sem eles, jun e ago/2026 ficariam um décimo abaixo do publicado
  (47,1% e 34,7%, contra 47,2% e 34,8%).
- **Yield:** a receita dividida pelos assentos-km, com a distância em linha
  reta entre a origem e o destino do passageiro (haversine, raio de
  6.371 km, em `sql/14_distancia.sql`), só nos pares com coordenada nas duas
  pontas. É a razão entre as somas: a média dos yields de cada tarifa,
  ponderada pelos assentos, cai 6,9% em 2025, longe dos 4,9% do Anuário; a
  razão cai 4,65%. Em valores de dez/2025, 2025 dá R$ 0,50/km.

## Mercados só de conexão (etapa 6)

Como origem e destino são os do passageiro, as tarifas têm pares de cidades
que nenhum voo direto liga: a viagem troca de voo no caminho. Na coleta de
13/10/2026, 256.224 dos 285.781 mercado-meses com tarifa (par de cidades sem
direção, no mês) não têm nenhum passageiro de voo regular na base
estatística, e somam 41.011.634 dos 225.811.030 assentos vendidos fora dos
pares da mesma cidade: 18,16%. Ali, a participação de cada grupo, que o
projeto mede pelo passageiro de voo direto, não existe, e a análise de
concorrência não chega nesses assentos.

---

# Voo Regular Ativo (VRA)

**Fonte:** [página do conjunto](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/voo-regular-ativo-vra)
e [metadados](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/voo-regular-ativo-vra/62-voo-regular-ativo-vra).
Os arquivos ficam numa listagem de pastas, uma por mês:
`https://sistemas.anac.gov.br/dadosabertos/Voos e operações aéreas/Voo Regular Ativo (VRA)/AAAA/MM - Mês/VRA_AAAAM.csv`.
A pasta tem o nome do mês por extenso e com acento (`03 - Março`), e o arquivo
leva o mês sem zero à esquerda (`VRA_20203.csv`, `VRA_202010.csv`). Cada mês
tem também uma versão em JSON.

**O que foi aberto:** a listagem dos 92 meses de jan/2019 a ago/2026 (1,07 GB
em CSV), quatro meses inteiros (jan/2019, mar/2020, abr/2020 e ago/2026) e o
começo de jan e fev/2020.

## O que é uma linha

**Uma etapa de voo**: uma decolagem e o pouso seguinte, com horários previstos
e realizados. Um voo com escala vira duas linhas.

O mês do arquivo é o da partida prevista. Pelos metadados, os dados "referem-se
a etapas cujas decolagens estavam previstas para o mês em questão ou, no caso de
etapas não planejadas, cujas decolagens ocorreram efetivamente nesse período".
Em ago/2026, 85.742 linhas têm partida prevista em agosto, 2.307 não têm
partida prevista (etapas não planejadas, todas realizadas) e 15 têm partida
prevista em setembro.

**Cópias exatas:** 77 linhas de jan/2019 e 44 de ago/2026 repetem outra linha
coluna por coluna. O mesmo voo de jan/2019 aparece até 4 vezes. O grão
declarado só vale depois de tratar essas cópias.

**No período inteiro, voos que se repetem sem ser cópia (etapa 3).** Depois
do filtro de voo doméstico regular, são 275 cópias exatas, algumas do mesmo
voo em dois arquivos. E 168 voos (mesma empresa, número, origem, destino e
partida prevista) têm registros que se contradizem, quase todos de 2019: o
mesmo voo como `CANCELADO` e como `REALIZADO`, ou realizado duas vezes com
horários diferentes. A staging fica com o realizado, que tem horário real
como evidência, e, entre dois realizados, com o que partiu primeiro.

## Colunas

| Coluna no arquivo | Conteúdo |
|---|---|
| `ICAO Empresa Aérea` | Designador OACI da empresa que operou a etapa |
| `Número Voo` | Número do voo, como texto (`0084`, `Z6582`) |
| `Código Autorização (DI)` | Dígito Identificador: o tipo de autorização da etapa (tabela abaixo) |
| `Código Tipo Linha` | Tipo de linha: doméstica ou internacional, de passageiro ou cargueira (tabela abaixo) |
| `ICAO Aeródromo Origem` / `Destino` | Códigos OACI. Inclui aeroportos estrangeiros |
| `Partida Prevista` / `Partida Real` | Data e hora, `AAAA-MM-DD hh:mm:ss`, horário de Brasília. Alguns trazem fração de segundo (`06:20:00.100000000`) |
| `Chegada Prevista` / `Chegada Real` | Idem |
| `Situação Voo` | `REALIZADO`, `CANCELADO` ou, a partir de abr/2020, `NÃO INFORMADO` |
| `Código Justificativa` | Motivo do atraso ou cancelamento (`AT`, `RA`, `MX`...). Desde abr/2020 é sempre `N/A`: o campo deixou de ser exigido com a revogação da IAC 1504 |

Os metadados listam mais campos (nome da empresa, modelo e assentos da
aeronave, situação na partida e na chegada) que não estão no CSV.

Nas três amostras com horário legível, todo voo cancelado (ou não informado)
tem os dois horários reais nulos, e todo voo realizado tem os dois preenchidos.

## Formato

| Característica | O que as amostras mostram |
|---|---|
| Encoding | UTF-8 com BOM |
| Primeira linha | **Não é o cabeçalho**: `Atualizado em: 2026-10-07`. O cabeçalho vem na segunda |
| Separador e aspas | `;`, todo campo entre aspas |
| Fim de linha | `\r\n` |
| Valor ausente | O texto `"null"`, não campo vazio |

## Fuso horário: Brasília, conferido nos dados

Os metadados dizem que os quatro horários estão em horário de Brasília. A
conferência: se partida e chegada estivessem cada uma no fuso local, a ida
Brasília → Rio Branco (duas horas atrás) pareceria quatro horas mais curta que
a volta. Em ago/2026, a mediana da duração prevista é quase igual nos dois
sentidos das rotas que cruzam fuso:

| Rota | Ida (min) | Volta (min) |
|---|---|---|
| Guarulhos ↔ Manaus | 235 | 230 |
| Brasília ↔ Rio Branco | 205 | 200 |
| Recife ↔ Fernando de Noronha | 80 | 75 |

Consequência pra etapa 9: o mapa de calor por hora mostra a hora de Brasília.
Em Manaus, o relógio local está uma hora atrás; em Rio Branco, duas.

## Códigos

Duas tabelas oficiais, porque a regra mudou dentro do período do projeto:
até mar/2020 vale a [IAC 1504](https://pergamum.anac.gov.br/pergamum/vinculos/IAC1504.pdf);
a partir de abr/2020, a [descrição de variáveis](https://www.gov.br/anac/pt-br/assuntos/regulados/empresas-aereas/Instrucoes-para-a-elaboracao-e-apresentacao-das-demonstracoes-contabeis/descricao-de-variaveis)
dos dados estatísticos.

**Dígito Identificador (DI)**

| Código | Até mar/2020 (IAC 1504) | A partir de abr/2020 |
|---|---|---|
| `0` | Voo regular | Etapa regular |
| `1` | Voo extra com HOTRAN | Não consta (aparece em 610 linhas de ago/2026) |
| `2` | Voo extra sem HOTRAN | Etapa extra |
| `3` | Voo de retorno | Etapa de retorno |
| `4` | Inclusão de etapa em voo previsto em HOTRAN | Inclusão de etapa |
| `5` | Voo cargueiro não regular | Não consta |
| `6` | Voo de serviço | Etapa não remunerada sem transporte de objetos |
| `7` | Voo de fretamento | Etapa de voo de fretamento |
| `8` | Voo de conexão para atender viagem internacional | Não consta |
| `9` | Voo charter | Etapa de voo charter |
| `A` / `B` | Voo de instrução / de experiência | Não constam |
| `D` | Não consta | Etapa de voo duplicada |
| `E` | Não consta | Etapa não remunerada com transporte de objetos |

A descrição de variáveis agrupa os DI em regular (`0`, `4` ou `C`), não regular
(`1`, `2`, `5`, `7`, `8`, `9` ou `D`) e improdutivo (os demais).

**Tipo de linha**

| Código | Até mar/2020 (IAC 1504) | A partir de abr/2020 |
|---|---|---|
| `N` | Nacional | Doméstica mista (passageiros ou mista) |
| `C` | Cargueiro doméstico | Doméstica cargueira |
| `I` | Internacional | Internacional mista |
| `G` | Cargueiro internacional | Internacional cargueira |
| `R` / `H` | Regional / sub-regional | Não constam |
| `E` / `L` | Especial / rede postal | Não constam |
| `X` | Não consta | Não consta. Em abr/2020 são 1.063 linhas, e as oito empresas com mais linhas são estrangeiras (Lufthansa Cargo, UPS e United entre elas). Nos dados estatísticos, `X` aparece como "NÃO IDENTIFICADA" |
| `NA` | Não consta | Não consta. 477 linhas, de dez/2020 a jul/2025, todas de voo cancelado; 325 entre aeroportos brasileiros |

**O filtro de voo doméstico regular de passageiros (etapa 3):** tipo de linha
`N` (e também `R` e `H` até mar/2020), DI do grupo regular (`0` ou `4`) e os
dois aeroportos no Brasil. O que o período inteiro mostrou sobre ele:

- O DI `C`, regular pela descrição de variáveis, não aparece. O DI vem vazio
  em 708 linhas, todas internacionais ou cargueiras, de jan/2019 a mar/2020.
- `R` só aparece de mar/2019 a mar/2020, e `H` só em fev e mar/2020, os
  meses corrompidos.
- **Tipo `N` não garante voo doméstico.** 9 voos marcados assim ligam o
  Brasil a Lisboa, Montevidéu, Bogotá, Córdoba, Paramaribo e Punta Cana, e um
  da Aerolíneas Argentinas vai de Cancún a Buenos Aires. Daí a exigência dos
  dois aeroportos no Brasil, com código começando por `SB`, `SD`, `SI`, `SJ`,
  `SN`, `SS` ou `SW`: os da América do Sul também começam por `S`.

## Dois meses perdidos: fev e mar/2020

Nos arquivos atuais de mar/2020, as quatro colunas de horário e a de situação
trazem o texto `Microsoft.SqlServer.Dts.Pipeline.BlobColumn` em vez do valor,
um defeito da exportação feita pela ANAC. São todas as 258.092 linhas, e
242.726 delas são cópias exatas de outra. O JSON do mesmo mês tem o mesmo
defeito. Em fev/2020 também são todas as linhas, 323.676 (conferido na etapa
3). Os dois arquivos têm 88 e 70 MB, contra 11 a 13 MB de um mês normal, e
dizem `Atualizado em: 2021-09-16` e `2021-09-17`.

A [versão descontinuada](https://www.gov.br/anac/pt-br/assuntos/dados-e-estatisticas/historico-de-voos/historico-de-voos-descontinuada)
do histórico de voos, publicada até out/2024, tem os dois meses legíveis, em
outro formato: sem aspas, cabeçalho sem acento (`ICAO Empresa Aerea;Numero
Voo;Codigo DI;...`), datas `dd/mm/aaaa hh:mm` e linhas terminadas só em `\r`.

**Decisão da etapa 3: os dois meses ficam fora.** São 2 de 92 meses, nenhuma
das três perguntas depende deles, e a cópia descontinuada pediria outra fonte
no coletor, em outro formato, numa página que a ANAC já descontinuou. A
staging descarta as linhas pelo conteúdo corrompido, não pelo mês: se a ANAC
consertar os arquivos, os dois meses voltam sozinhos. Um teste avisa se o
defeito aparecer em outro arquivo.

## Atraso: datas erradas e voos que mudaram de dia

A staging calcula o atraso na chegada, em minutos, pela diferença entre a
chegada real e a prevista. Nos 5,2 milhões de voos do período, a mediana do
atraso de cada mês fica entre -13 min (abr/2020) e 0, mas as pontas
misturam três coisas:

| O que se vê | Quantos | O que é |
|---|---|---|
| Mais de dois dias de diferença | 8 voos | Data digitada errada: ano trocado (2022 por 2023), dia e mês invertidos (01/04 por 04/01), mês trocado. A staging deixa o atraso nulo e mantém o voo |
| Chegada de 2 a 23 h antes do previsto | 964 voos | Voo antecipado de verdade: partiu mais de uma hora antes, e a duração real é a prevista (mediana de 3 min de diferença) |
| Cerca de 24 h antes ou depois | Picos de uns mil voos em -24 h e de uns 260 em +24 h | Voo que mudou de dia, ou data com um dia de erro. Não dá pra separar, e fica como está |

## Revisão

A ANAC republica a série. Quase todos os arquivos de abr/2020 a ago/2026 têm
data de 07/10/2026, e os de 2019, de 12/05/2026. A primeira linha de cada
arquivo diz quando ele foi gerado.

---

# Dados estatísticos do transporte aéreo

**Fonte:** [página do conjunto](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/dados-estatisticos-do-transporte-aereo),
[metadados](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/voos-e-operacoes-aereas/dados-estatisticos-do-transporte-aereo/48-dados-estatisticos-do-transporte-aereo)
e [descrição de variáveis](https://www.gov.br/anac/pt-br/assuntos/regulados/empresas-aereas/Instrucoes-para-a-elaboracao-e-apresentacao-das-demonstracoes-contabeis/descricao-de-variaveis).

## Duas publicações da mesma base

| | Arquivo acumulado | Arquivos mensais |
|---|---|---|
| Onde | [Dados abertos](https://sistemas.anac.gov.br/dadosabertos/Voos%20e%20opera%C3%A7%C3%B5es%20a%C3%A9reas/Dados%20Estat%C3%ADsticos%20do%20Transporte%20A%C3%A9reo/): `Dados_Estatisticos.csv` | [Envio de informações](https://www.gov.br/anac/pt-br/assuntos/regulados/empresas-aereas/Instrucoes-para-a-elaboracao-e-apresentacao-das-demonstracoes-contabeis/envio-de-informacoes): `basica/AAAA/basicaAAAA-MM.zip` e `combinada/AAAA/combinadaAAAA-MM.zip` |
| Período | jan/2000 a ago/2026, num arquivo só | Um zip por mês e por tipo, até ago/2026 |
| Tamanho | 360 MB | 7 a 9 MB por zip; descompactado, 82 MB (básica) e 167 a 174 MB (combinada) por mês |
| Grão | Empresa × mês × par de aeródromos × natureza × grupo de voo | Uma etapa (básica) ou um par embarque-desembarque de um voo (combinada) |

Nos 92 meses do projeto, os mensais descompactados passariam de 7 GB (básica) e
de 15 GB (combinada), pela média dos dois meses abertos. O acumulado traz o
que o projeto precisa em 360 MB, e a comparação abaixo mostra de onde vem cada
número dele.

**O que foi aberto:** o acumulado inteiro (1.099.729 linhas, 272.717 desde
2019) e os mensais de jan/2019 e ago/2026.

## Básica e combinada, segundo a ANAC

- **Etapa básica**: "realizadas pela aeronave desde a sua decolagem até o
  próximo pouso". É a perna do voo: os passageiros a bordo entre dois
  aeródromos, venham de onde vierem.
- **Etapa combinada** (*on flight origin and destination*): o par entre o
  aeródromo onde o passageiro embarcou e o aeródromo onde desembarcou, dentro
  do mesmo voo, independentemente de escalas. O campo `cd_cotran` diz se ele
  desembarcou de vez (`N`) ou se seguiu em outro voo do mesmo contrato (`D`,
  trânsito doméstico; `I`, internacional).

Nenhuma das duas é a viagem do passageiro de ponta a ponta. Quem vai de
Cuiabá a Recife trocando de avião em Brasília aparece como dois pares, um em
cada voo. Já a tarifa registra a viagem inteira, de Cuiabá a Recife.

## De onde vem cada número do acumulado

Ago/2026, mercado doméstico, as três publicações lado a lado:

| | Básica | Combinada | Acumulado |
|---|---|---|---|
| Passageiros pagos | 8.970.271 | 8.940.607 | **8.940.607** |
| Assentos oferecidos | 11.158.665 | não tem | **11.158.665** |
| Decolagens | 70.110 | não tem | **70.110** |
| RPK | 9.912.786.642 | não tem | **9.912.786.642** |
| ASK | 12.017.128.188 | não tem | **12.017.128.188** |

**O acumulado junta as duas:** passageiros vêm da combinada; assentos,
decolagens, distância, ASK e RPK, da básica. No doméstico de ago/2026, 1.854
linhas têm passageiros e 1.831 têm ASK: são 23 pares só de embarque e
desembarque, sem perna direta. Numa rota sem escala as três publicações
coincidem: Congonhas → Santos Dumont, em ago/2026, tem 27.257 passageiros da
Azul, 75.665 da Gol e 65.675 da Latam (código `TAM`) nas três.

**Conexões pesam.** Na combinada de ago/2026, 23,5% dos passageiros pagos
domésticos estão em trânsito (`cd_cotran` `D` ou `I`): 2.105.240 de 8.940.607.
É a parcela em que o par do voo e a viagem do passageiro não coincidem.

## Colunas do acumulado que o projeto usa

| Coluna | Conteúdo |
|---|---|
| `EMPRESA_SIGLA`, `EMPRESA_NOME`, `EMPRESA_NACIONALIDADE` | Empresa que operou. Nome e nacionalidade por extenso |
| `ANO`, `MES` | Data prevista da primeira etapa do voo. `MES` sem zero à esquerda |
| `AEROPORTO_DE_ORIGEM_SIGLA` / `_DESTINO_SIGLA` | Código OACI. Mais nome, UF, região, país e continente. O "nome" é o da cidade, não o do aeroporto: nos dez conferidos na etapa 5, `SBGL` vem como RIO DE JANEIRO e `SBGR` como GUARULHOS |
| `NATUREZA` | `DOMÉSTICA` quando pouso e decolagem são no Brasil e a empresa é brasileira; senão `INTERNACIONAL` |
| `GRUPO_DE_VOO` | `REGULAR`, `NÃO REGULAR` ou `IMPRODUTIVO` |
| `PASSAGEIROS_PAGOS`, `PASSAGEIROS_GRATIS` | Da combinada. Pagos incluem quem viaja com milhas e com promoção |
| `ASSENTOS`, `DECOLAGENS`, `ASK`, `RPK` | Da básica |
| `DISTANCIA_VOADA_KM` | Soma da distância de todas as decolagens. Dividida por `DECOLAGENS`, dá a distância da etapa: 366 km de Congonhas a Santos Dumont, igual ao `km_distancia` da básica |

Grão conferido: nenhuma combinação de empresa, ano, mês, origem, destino,
natureza e grupo de voo se repete nas 1.099.729 linhas. Desde 2019, natureza
doméstica só aparece com empresa brasileira, como diz a definição. Só 7
linhas, todas de 2019, internacionais e de empresas estrangeiras, vêm sem
aeroporto de origem.

**A distância vem pronta.** A ANAC a calcula "considerando a curvatura do
planeta terra". A haversine da etapa 5 vai ser conferida com ela.

**Origem igual ao destino (etapa 5).** Das 179.817 linhas domésticas desde
2019, 6.098 têm o mesmo aeroporto na origem e no destino, em 130
aeroportos, com 415.437 passageiros pagos. Quase tudo é do grupo
improdutivo: 5.481 linhas e 404.697 passageiros, 97,9% dos passageiros pagos
do grupo. É compatível com a etapa de retorno (DI `3`), que a descrição de
variáveis põe no grupo improdutivo: o avião volta pro aeroporto de onde
saiu. No regular são 325 linhas e 8.849 passageiros. O modelo da etapa 5
deixa essas linhas de fora, porque um aeroporto com ele mesmo não forma
mercado.

## Formato

| | Acumulado | Mensais (`.txt` dentro do zip) |
|---|---|---|
| Encoding | UTF-8 com BOM | Latin-1 |
| Primeira linha | `Atualizado em: 2026-10-13`, e o cabeçalho na segunda | O cabeçalho |
| Separador, aspas | `;`, todo campo entre aspas | `;`, só texto entre aspas |
| Decimal | Números inteiros, exceto `HORAS_VOADAS`, com vírgula (`5,133`) | Vírgula |
| Fim de linha | `\r\n` | `\r\n` |
| Colunas | 38 | 111 (básica) e 90 (combinada) |

O acumulado é regerado com frequência: a data na primeira linha e a do
arquivo na listagem eram as do próprio dia da conferência (13/10/2026). Um
sha256 novo a cada coleta não quer dizer revisão de dado.

## Empresas

As empresas com passageiro doméstico regular de jan/2019 a ago/2026, por
passageiros pagos no período:

| Código | Nome no arquivo | Passageiros pagos |
|---|---|---|
| `TAM` | TAM LINHAS AÉREAS S.A. | 225,7 milhões |
| `GLO` | GOL LINHAS AÉREAS S.A. (EX- VRG LINHAS AÉREAS S.A.) | 198,7 milhões |
| `AZU` | AZUL LINHAS AÉREAS BRASILEIRAS S/A | 189,2 milhões |
| `PTB` | PASSAREDO TRANSPORTES AÉREOS S.A. | 3,2 milhões |
| `ONE` | OCEANAIR LINHAS AÉREAS S.A. (AVIANCA) | 3,1 milhões |
| `PAM` | MAP TRANSPORTES AÉREOS LTDA. | 460 mil |
| `ACN` | AZUL CONECTA LTDA. (EX TWO TAXI AEREO LTDA) | 365 mil |
| `IPM` | ITAPEMIRIM TRANSPORTES AEREOS LTDA | 300 mil |
| `ABJ`, `SUL`, `CQB`, `ASO` | Abaeté, ASTA, Apuí e Aerosul | menos de 30 mil cada |

Código e grupo econômico são coisas diferentes: `ACN`, a Azul Conecta, é o
caso que a etapa 5 resolve em `grupos.csv`, com fonte.

**As empresas das três bases (etapa 5).** São 24 códigos: 11 nas tarifas,
22 na base estatística doméstica, contando as de carga e de fretamento, e
19 no VRA. Dois casos que só aparecem juntando as bases:

- **A TwoFlex tem dois códigos.** É `OWT` nas tarifas (de jan a ago/2019) e
  no VRA (de jan/2019 a nov/2021), e `ACN` na base estatística, que a chama
  "AZUL CONECTA LTDA. (EX TWO TAXI AEREO LTDA)" desde jan/2019. No VRA, os
  mesmos números de voo passam de `OWT` pra `ACN` ao longo de 2021.
- **`DSM`, a LATAM Argentina, tem um voo só**, no VRA: de Viracopos a
  Guarulhos, em jan/2020.

O grupo de cada empresa, com o período e a fonte, está em
[`dados/referencia/grupos.csv`](dados/referencia/grupos.csv).

---

# Aeródromos públicos

**Fonte:** [lista de aeródromos públicos](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/aerodromos/aerodromos-publicos/lista-de-aerodromos-publicos)
e [metadados](https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/aerodromos/aerodromos-publicos/lista-de-aerodromos-publicos/metadados-do-conjunto-de-dados-lista-de-aerodromos-publicos-v2).
Um arquivo só, `AerodromosPublicos.csv`, na [listagem](https://sistemas.anac.gov.br/dadosabertos/Aerodromos/Aer%C3%B3dromos%20P%C3%BAblicos/Lista%20de%20aer%C3%B3dromos%20p%C3%BAblicos/)
do portal (99 KB, de 01/10/2026). Periodicidade, pelos metadados:
"Aproximadamente a cada 40 dias".

## O que é uma linha

**Um aeródromo público**: 496 linhas, 496 códigos OACI distintos, nenhum vazio.
Todos com 4 letras e prefixo brasileiro (`SB` 132, `SN` 125, `SS` 95, `SD` 67,
`SW` 57, `SJ` 13, `SI` 7).

## Colunas que o projeto usa

O arquivo tem 18 colunas, e não as dos metadados: os metadados descrevem as
pistas, que não estão no CSV, e não descrevem as coordenadas decimais, que
estão.

| Coluna | Conteúdo |
|---|---|
| `Código OACI` | 4 letras, o mesmo código das outras três bases. Não há código IATA neste arquivo; ele está nos mensais da base estatística (`sg_iata_origem`) |
| `Nome` | Nome do aeródromo |
| `Município`, `UF` | Município onde fica o ponto de referência. **Vazios em 170 linhas**, Congonhas, Santos Dumont, Pampulha e Brasília entre elas. UF por extenso (`Acre`), não a sigla |
| `Município Servido`, `UF Servido` | Cidade principal atendida. Vazios em 2 linhas. É o campo que diz a cidade |
| `LATGEOPOINT`, `LONGEOPOINT` | Coordenadas em graus decimais, com ponto (`-23.626111`). Todas convertem e caem dentro do Brasil |
| `Latitude`, `Longitude` | As mesmas coordenadas em graus, minutos e segundos (`23°37'34"S`). WGS-84, pelos metadados |
| `Altitude` | Metros, com vírgula decimal |

Conferência do plano para a etapa 3: Congonhas (`SBSP`) fica em -23,626111 e
-46,656389, dentro de São Paulo.

**Município não é cidade atendida.** O município calculado pelas coordenadas
traz Guarulhos (`SBGR`) em "SÃO PAULO", o Galeão (`SBGL`) em "DUQUE DE CAXIAS"
e o aeroporto de Salvador (`SBSV`) em "LAURO DE FREITAS". Já o município
servido de Confins (`SBCF`) é "Confins", e não Belo Horizonte. Nenhum dos dois
campos agrupa os aeroportos de uma mesma região metropolitana, o que
justifica a tabela de mercados da etapa 1.

## Formato

| Característica | O que o arquivo mostra |
|---|---|
| Encoding | Latin-1 (não decodifica como UTF-8) |
| Primeira linha | `Atualizado em: 2026-10-01`, e o cabeçalho na segunda |
| Separador | `;` |
| Aspas | Nenhum campo vem entre aspas. As 992 aspas do arquivo são o símbolo dos segundos nas coordenadas (`09°52'06"S`), e o leitor de CSV não pode tratá-las como delimitador |
| Fim de linha | `\r\n` |

## Aeroportos das outras bases que não estão na lista

A lista só tem os aeródromos **públicos** cadastrados. Nas amostras de
ago/2026, aparecem fora dela:

| Código | Onde aparece | Onde está |
|---|---|---|
| `SSOU` | Tarifas e VRA | Lista de [aeródromos privados](https://sistemas.anac.gov.br/dadosabertos/Aerodromos/Aer%C3%B3dromos%20Privados/Lista%20de%20aer%C3%B3dromos%20privados/Aerodromos%20Privados/): Aripuanã (MT) |
| `SNCL` | Tarifas e VRA | Lista de privados: Lorenzo, em Cairu (BA) |
| `SBUY` | VRA | Lista de privados: Urucu, em Coari (AM) |
| `SBFC`, `SBCM` | Tarifas (`SBFC`) e VRA (`SBCM`) | Nem na lista de públicos, nem na de privados. A de [públicos excluídos](https://sistemas.anac.gov.br/dadosabertos/Aerodromos/Aer%C3%B3dromos%20P%C3%BAblicos/Aerodromos%20Excluidos/) não tem coluna de código OACI, só CIAD e nome |

**No período inteiro (etapa 3).** As três bases, depois da staging, usam 306
aeroportos brasileiros: 248 estão na lista pública, 40 na de privados e 18 em
nenhuma das duas. Somados, os 58 de fora da lista pública respondem por 0,26%
dos assentos vendidos nas tarifas e 0,02% dos passageiros pagos regulares da
base estatística. São poucos, mas existem, e é por isso que a `dim_aeroporto`
(etapa 5) não pode depender só da lista pública, e o teste "aeroporto sem
mercado vira lista, não some" tem caso real pra pegar.

Os 18 sem lista, com o nome que a base estatística dá quando o código
aparece nela: `SBBT` (Barretos), `SBBZ` (Armação dos Búzios), `SBCM`
(Forquilhinha), `SBCO` (Canoas), `SBGS` (Ponta Grossa), `SBJC` (Belém),
`SBMN` (Manaus), `SBNT` (Parnamirim), `SBQV` (Vitória da Conquista), `SBRG`
(Rio Grande), `SBTS` (Óbidos), `SBYS` (Pirassununga), `SNAT` (Aracati) e
`SNJN` (Januária). `SBFC`, `SBFE`, `SBGU` e `SNOB` ficam sem nome: aparecem
nas tarifas ou no VRA, mas não na base estatística.

Na `dim_aeroporto` (etapa 5), os 14 ficam com essa cidade e a UF da base
estatística, e os 4 só com o código. Nenhum dos 18 tem coordenada: a
distância dos mercados deles vem da base estatística quando há voo direto
(43 mercados), e 428 mercados, com 0,06% dos assentos vendidos, ficam sem
distância.

## A lista de privados

`AerodromosPrivados.csv`, na [listagem](https://sistemas.anac.gov.br/dadosabertos/Aerodromos/Aer%C3%B3dromos%20Privados/Lista%20de%20aer%C3%B3dromos%20privados/Aerodromos%20Privados/)
do portal: 3.924 linhas, de 13/10/2026. Mesmo encoding (Latin-1), mesma
primeira linha (`Atualizado em`), mesmo separador e nenhuma aspa delimitando
campo, como a lista pública. O resto muda:

| | Lista pública | Lista de privados |
|---|---|---|
| Colunas | 18 | 24, em outra ordem; as das pistas estão no arquivo |
| Coordenadas em graus, minutos e segundos | `Latitude` e depois `Longitude` | `Longitude` antes de `Latitude`. Os segundos têm casas decimais em 1.139 linhas (`19°33'33,46"S`) |
| Coordenadas decimais | `LATGEOPOINT`, `LONGEOPOINT`, com ponto | As mesmas colunas, no fim do arquivo, **com vírgula** (`-4,8830556`). Preenchidas nas 3.924 linhas |
| Cidade | `Município Servido` | Só `Município`, em maiúsculas (`COARI`) |
| UF | Por extenso (`Acre`) | Sigla (`AM`) |

Na lista de privados, o decimal descarta a fração de segundo: `19°33'33,46"S`
vira `-19,559167`, que é 33,00". A diferença chega a 1" (uns 30 m), e o grau,
minuto e segundo é o mais preciso dos dois. Na pública, os segundos são
inteiros e as duas colunas coincidem.

Três defeitos que o leitor precisa tratar:

- **23 linhas sem código OACI.**
- **Três códigos repetidos em aeródromos diferentes:** `SD09` (uma fazenda no
  MT e Cidade de Goiás, GO), `SS3G` e `SS7V`. Nenhum dos três aparece nas
  outras bases.
- **Uma coordenada impossível:** `SJ1Z` (Fazenda Jeovazão, sem município nem
  UF) está a leste de Greenwich, `047°04'39,42"E`, e o decimal diz outra
  coisa ainda (`47,2108333`, ou seja, 47°12'39"). O Brasil inteiro fica a
  oeste.

---

# Marts e dimensões (`dados/marts/`)

Os arquivos que a construção grava pra análise e pro painel, versionados no
git e lidos pelos notebooks pela URL do GitHub. Cada um sai de um `.sql` em
`sql/`, que explica as decisões; aqui fica o que é preciso pra usar o arquivo
sem abrir o SQL: o que é uma linha, as colunas, a unidade e o que não se
soma. Contagens da coleta de 13/10/2026, conferidas nos arquivos em
19/10/2026.

Três regras valem pra todos:

- **Reais são nominais.** Nenhum mart corrige pela inflação; o notebook
  `01-validacao` mostra como levar ao preço de um mês pelo IPCA.
- **Média sai da razão entre somas**, nunca da média das linhas: tarifa média
  é a receita dividida pelos assentos vendidos; tarifa por km, a receita
  dividida pelos assentos-km (ver "Como a tarifa média é calculada"). Assim a
  conta continua certa em qualquer recorte: ano, grupo, mercado.
- **O mês é o dia 1** (`2026-08-01` é ago/2026) e liga com `dim_calendario`.
  Mas o mês quer dizer coisas diferentes em cada base: o da venda nas
  tarifas, o do voo na base estatística, o do arquivo no VRA.

## `validacao.parquet`

**Uma linha por mês e empresa**: 1.188 linhas, nos 92 meses de jan/2019 a
ago/2026, das 24 empresas que aparecem em alguma das três bases. São os
totais que a ANAC publica, pra conferir a base contra os números oficiais
(`sql/40_mart_validacao.sql`, notebook `01-validacao`). Empresa ausente numa
base, no mês, fica com zero nas colunas dela.

A empresa também muda de sentido: nas tarifas, é a que vendeu; na base
estatística e no VRA, a que operou. Colunas de bases diferentes não descrevem
as mesmas viagens, e a razão entre elas (receita das tarifas por passageiro
da base estatística, por exemplo) não é tarifa de ninguém.

| Coluna | Base | Unidade | O que é |
|---|---|---|---|
| `mes` | todas | data, dia 1 | Chave de `dim_calendario` |
| `empresa` | todas | código OACI | Chave de `dim_empresa` |
| `assentos_vendidos` | tarifas | assentos | Soma dos assentos vendidos |
| `receita_tarifas` | tarifas | R$ nominais | Soma de tarifa vezes assentos |
| `assentos_ate_300` | tarifas | assentos | Vendidos a até R$ 300, inclusive |
| `assentos_ate_500` | tarifas | assentos | Vendidos a até R$ 500, inclusive: contém os de `assentos_ate_300` |
| `assentos_acima_1500` | tarifas | assentos | Vendidos acima de R$ 1.500 |
| `receita_com_distancia` | tarifas | R$ nominais | A receita só dos pares de aeroportos com coordenada nas duas pontas |
| `assentos_km` | tarifas | assentos-km | Assentos vezes a distância em linha reta do par, nos mesmos pares |
| `passageiros_pagos` | base estatística | passageiros | Pagos, de todos os grupos de voo; incluem quem viaja com milhas |
| `passageiros_pagos_regular` | base estatística | passageiros | Só os de voo regular: contidos em `passageiros_pagos` |
| `decolagens` | base estatística | decolagens | |
| `rpk` | base estatística | passageiros-km | Passageiros pagos vezes a distância voada |
| `ask` | base estatística | assentos-km | Assentos oferecidos vezes a distância voada |
| `voos` | VRA | etapas de voo | Todas as do arquivo do mês, em qualquer situação |
| `voos_realizados` | VRA | etapas de voo | Situação `REALIZADO` |
| `voos_cancelados` | VRA | etapas de voo | Situação `CANCELADO` |
| `voos_atraso_15`, `voos_atraso_30`, `voos_atraso_60` | VRA | etapas de voo | Chegaram mais de 15, 30 e 60 minutos depois do previsto: cada uma contém a seguinte |

Todas as colunas, menos `mes` e `empresa`, se somam entre meses e empresas.
O que não se faz é somar as que se contêm: as faixas de preço, os dois
passageiros e os três atrasos. O yield é `receita_com_distancia` dividida por
`assentos_km`, e não `receita_tarifas`: a receita sem distância não tem
assento-km no denominador.

## `mercado_mes.parquet`

**Uma linha por mês, mercado e grupo**: 75.147 linhas, nos 30.886
mercado-meses com passageiro de voo regular, de 1.089 mercados. É a base da
comparação entre concorrência e preço (`sql/50_mart_mercado.sql`, notebooks
`02-concorrencia-e-preco` e `03-comparar-o-comparavel`). Os mercados só de
conexão, sem voo direto, ficam de fora, com 18,16% dos assentos vendidos
(ver "Mercados só de conexão").

Entra o grupo que, no mercado e no mês, teve passageiro ou vendeu tarifa. Por
isso 29.140 linhas não têm passageiro regular, e a participação delas é zero:
28.288 venderam tarifa sem voo regular no mercado (964 delas com
fretamento), e 852 só fizeram fretamento. E 3.812 linhas não têm tarifa
vendida.

Tarifa e passageiro não são as mesmas viagens: a tarifa é do grupo que
vendeu, no mês da venda; o passageiro, do grupo que operou, no mês do voo. A
linha junta os dois como retrato da estrutura do mercado, e não como o preço
pago por aqueles passageiros.

| Coluna | Unidade | O que é |
|---|---|---|
| `mes` | data, dia 1 | Chave de `dim_calendario`: mês do voo pros passageiros, da venda pras tarifas |
| `mercado` | chave | Par de cidades sem direção, chave de `dim_mercado` |
| `grupo` | chave | Grupo econômico, chave de `dim_grupo` |
| `passageiros_pagos` | passageiros | Pagos de voo regular, do grupo que operou. É o passageiro do voo: quem troca de avião conta uma vez em cada voo |
| `passageiros_nao_regular` | passageiros | Os do fretamento (`NÃO REGULAR`), fora da participação, pra servir de sensibilidade |
| `participacao` | fração, de 0 a 1 | `passageiros_pagos` do grupo dividido pelos do mercado no mês |
| `concorrentes` | grupos | Grupos com pelo menos 5% dos passageiros do mercado no mês |
| `hhi` | pontos, até 10.000 | Soma dos quadrados das participações, vezes 10.000. Vai de 10.000/n, com n grupos iguais, a 10.000, com um grupo só |
| `assentos_vendidos` | assentos | Vendidos pelo grupo no mercado |
| `receita` | R$ nominais | Soma de tarifa vezes assentos |
| `assentos_km` | assentos-km | Assentos vendidos vezes a `distancia_km` do mercado; nulo se o mercado não tem distância |

**O que não se soma:** `participacao`, `concorrentes` e `hhi` são medidas do
mercado no mês, repetidas em cada linha dele. A participação soma 1 dentro de
um mercado-mês e nada fora dele; o HHI e os concorrentes aparecem uma vez por
grupo, então contar mercado-meses ou tirar média de HHI pede uma linha por
`mes` e `mercado` antes.

**Tarifa por km:** a receita e os assentos-km das mesmas linhas, sem as que
têm `assentos_km` nulo, ou a receita delas entra sem distância e puxa a
tarifa por km pra cima. São 11 linhas, em 3 mercado-meses, com 580 assentos
vendidos.

## `fusao.parquet`

**Uma linha por janela e mercado**: 970 linhas. É a fusão Azul + GOL
simulada (`sql/60_mart_fusao.sql`, notebook `04-fusao`, README, "A fusão
Azul + GOL"). Duas janelas de 12 meses: `2024`, de jan a dez/2024, com 503
mercados, e `12 meses mais recentes`, contados do último mês da base, hoje de
set/2025 a ago/2026, com 467. Entra o mercado com passageiro de voo regular
na janela.

| Coluna | Unidade | O que é |
|---|---|---|
| `janela` | texto | `2024` ou `12 meses mais recentes` |
| `inicio`, `fim` | data, dia 1 | Primeiro e último mês da janela |
| `mercado` | chave | Chave de `dim_mercado` |
| `passageiros` | passageiros | Pagos de voo regular, somados na janela |
| `participacao_azul`, `participacao_gol` | fração, de 0 a 1 | A fatia de cada grupo nos passageiros da janela inteira, e não a média dos meses |
| `concorrentes_antes`, `concorrentes_depois` | grupos | Com pelo menos 5% dos passageiros, com os grupos de hoje e com Azul e GOL juntas |
| `hhi_antes`, `hhi_depois` | pontos, até 10.000 | HHI com o `grupo` e com o `grupo_simulado` de `dim_grupo` |
| `delta_hhi` | pontos | `hhi_depois` menos `hhi_antes`: 2 × 10.000 × `participacao_azul` × `participacao_gol` |
| `leitura` | texto | A faixa do guia do CADE de 2016, seção 2.4.2: `variação pequena`, `mercado não concentrado`, `potencial preocupação`, `presunção de poder de mercado` ou `sem leitura no guia` |

**O que não se soma:** o mesmo mercado aparece nas duas janelas, então
qualquer conta começa filtrando a `janela`. Dentro dela, só `passageiros` se
soma entre mercados; o resto é medida do mercado na janela. Com coleta nova,
os `12 meses mais recentes` andam junto.

## `pontualidade_rota.parquet` e `pontualidade_horario.parquet`

Os voos previstos do VRA, contados em dois recortes
(`sql/70_mart_pontualidade.sql`, notebook `05-pontualidade`). Contagens
conferidas nos arquivos em 20/10/2026:

- **`pontualidade_rota`**: uma linha por mês, grupo, aeroporto de origem e
  aeroporto de destino, com o mercado do par: 98.670 linhas. Serve ao
  aeroporto de partida, ao de chegada e ao mercado.
- **`pontualidade_horario`**: uma linha por mês, grupo, dia da semana e
  hora da partida prevista: 57.972 linhas.

Os dois somam o mesmo, 5.173.197 voos previstos. Voo previsto é o que tem
partida prevista: as 13.749 etapas não planejadas, todas realizadas, ficam
de fora, porque sem horário previsto não há atraso nem hora. O mês é o do
arquivo do VRA, e o grupo, o de quem operou.

| Coluna | Unidade | O que é |
|---|---|---|
| `mes` | data, dia 1 | Chave de `dim_calendario` |
| `grupo` | chave | Grupo de quem operou, chave de `dim_grupo` |
| `mercado` | chave | Só na rota: chave de `dim_mercado` |
| `origem`, `destino` | código OACI | Só na rota: chaves de `dim_aeroporto` |
| `dia_semana` | 1 a 7 | Só no horário: da partida prevista, de 1 (segunda) a 7 (domingo), o padrão ISO |
| `hora` | 0 a 23 | Só no horário: da partida prevista, no horário de Brasília |
| `voos_previstos` | voos | Todos os do registro: realizados, cancelados e não informados |
| `voos_realizados` | voos | Situação `REALIZADO` |
| `voos_cancelados` | voos | Situação `CANCELADO` |
| `voos_nao_informados` | voos | Situação `NÃO INFORMADO`: 1.158, de ago/2020 a out/2023 |
| `voos_medidos` | voos | Realizados com o atraso medido: todos menos os 8 com data trocada |
| `voos_atraso_15`, `voos_atraso_30`, `voos_atraso_60` | voos | Chegaram mais de 15, 30 e 60 minutos depois do previsto: cada uma contém a seguinte |
| `voos_adiantados_2h` | voos | Chegaram 2 h ou mais antes do previsto (1.817): contam como no horário |
| `voos_atraso_23h` | voos | Chegaram 23 h ou mais depois (263): estão dentro de `voos_atraso_60` |

Todas as contagens se somam entre linhas. O que não se faz é somar as que
se contêm: os previstos são os realizados, os cancelados e os não
informados, e os três cortes de atraso estão um dentro do outro. O
percentual de atraso é `voos_atraso_15` dividido por `voos_medidos`; o de
cancelamento, `voos_cancelados` dividido por `voos_realizados` mais
`voos_cancelados`, como no notebook 05. As duas pontas (2 h antes, 23 h
depois) são voos que os dados não separam de mudança de horário ou de dia
(ver "Atraso: datas erradas e voos que mudaram de dia").

## Dimensões

**`dim_calendario`**: um registro por mês, 92, de jan/2019 a ago/2026, sem
buraco: fev e mar/2020 estão nela, mesmo sem voo no VRA, pra o gráfico
mostrar o buraco em vez de pular o mês. Colunas: `mes` (a chave, dia 1),
`ano`, `trimestre`, `numero_mes` (1 a 12), `nome_mes` (`janeiro`),
`mes_abreviado` (`jan`) e `rotulo` (`jan/2019`).

**`dim_grupo`**: um registro por grupo econômico, 21. Colunas: `grupo` (a
chave, como em `dados/referencia/grupos.csv`), `nome_grupo` e
`grupo_simulado`, que é `AZUL+GOL` pra Azul e pra GOL e repete o `grupo` nos
demais.

**`dim_empresa`**: um registro por empresa, 24. Colunas: `empresa` (código
OACI), `nome_empresa` (o nome curto do `grupos.csv`) e `nome_anac` (o da base
estatística; nulo pra OWT e DSM, que não aparecem nela). Não tem o grupo,
porque o grupo muda no tempo (a TwoFlex é da Azul desde jun/2020; a MAP, da
VoePass desde set/2019): a ligação mês a mês fica no `grupos.csv`, e os marts
por grupo já trazem o grupo do mês. Pra juntar o `validacao.parquet` por
grupo, é o `grupos.csv` que diz de quem era cada empresa em cada mês.

**`dim_aeroporto`**: um registro por código OACI que aparece em alguma das
três bases, 306. Colunas: `icao` (a chave), `nome` (o do aeródromo, nas
listas da ANAC), `municipio`, `uf`, `latitude` e `longitude` (graus
decimais), `cidade` (a cidade do mercado: `SAO`, `RIO`, `BHZ` ou o próprio
código OACI), `nome_cidade` e `cadastro`, que diz de onde vieram os dados:
`lista publica` (248), `lista de privados` (40), `base estatistica` (14,
com município e UF em maiúsculas, sem nome nem coordenada) e `nenhum` (4, só
o código). Os 18 fora das listas são os sem coordenada (ver "Aeroportos das
outras bases que não estão na lista"). Não liga direto a nenhum mart: os
marts são por mercado, e o mercado liga às duas cidades.

**`dim_mercado`**: um registro por par de cidades, sem direção, que aparece
em alguma das três bases: 8.983, bem mais que os 1.089 do
`mercado_mes.parquet`, porque inclui os mercados só de conexão. Colunas:
`mercado` (a chave, as duas cidades em ordem alfabética: `RIO-SAO`),
`cidade_a`, `nome_cidade_a`, `cidade_b`, `nome_cidade_b`, `nome` (`Rio de
Janeiro – São Paulo`), `distancia_km` (uma casa decimal: a média das
distâncias dos pares de aeroportos do mercado, ponderada pelos assentos
vendidos) e `distancia_fonte`: `coordenadas` (8.512), `base estatistica`
(43, a distância voada dividida pelas decolagens) ou `nenhuma: sem
coordenada nem voo direto` (428, com `distancia_km` nula).

---

## Perguntas em aberto

- **Tarifas:** o `N` de `Tarifa-N`, no cabeçalho B, quer dizer "nominal"? Os
  metadados dizem que o valor é nominal, mas o cabeçalho não explica.
- **Tarifas:** a ANAC vai renomear o arquivo de mai/2026? Se renomear, o
  coletor precisa achar o mês pelo novo nome sem baixar duas vezes.
- **VRA:** o DI `1` não consta da tabela válida a partir de abr/2020, mas
  aparece em 610 linhas de ago/2026, quase todas sem partida prevista. Que
  tipo de etapa é?
- **VRA:** jan e fev/2019 ainda tinham horário de verão. A "hora de Brasília"
  desses dias é a de verão ou a padrão? Só afeta o mapa de calor dessas
  semanas.
- **VRA:** os voos a cerca de 24 h do horário previsto mudaram de dia ou têm a
  data com um dia de erro? Os dados não separam os dois casos.
- **Tarifas:** as 377 tarifas abaixo de R$ 10 e as 4 acima de R$ 10 mil são
  erro de registro ou tarifa de verdade? Nenhuma cai num mês com comunicado
  da ANAC pra conferir, e juntas somam 0,004% dos assentos: a resposta não
  muda nenhuma média.
- **Aeródromos:** onde estão os 18 aeroportos que não estão em nenhuma das
  duas listas (`SBFC` e `SBCM` entre eles)? A lista de excluídos não tem
  código OACI pra conferir. Sem coordenada, a distância sai da base
  estatística nos pares com voo direto, e 428 mercados ficam sem ela.
