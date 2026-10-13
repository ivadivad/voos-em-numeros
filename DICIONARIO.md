# Dicionário de dados

O que é cada base da ANAC usada no projeto, aberta e conferida antes de
qualquer linha de código (etapa 1). Onde uma característica foi conferida nos
dados, está dito em quantos arquivos ou linhas. Onde a fonte é a documentação
oficial, o link vai junto. Conferências feitas em 13/10/2026.

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
| Mês das linhas | Bate com o nome do arquivo nos 92 (primeiros 8 KB de cada) e nas duas amostras inteiras |

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

**O filtro de voo doméstico regular de passageiros (etapa 3):** tipo de linha
`N` (e também `R` e `H` até mar/2020) e DI do grupo regular (`0` ou `4`).

## Dois meses perdidos: fev e mar/2020

Nos arquivos atuais de mar/2020, as quatro colunas de horário e a de situação
trazem o texto `Microsoft.SqlServer.Dts.Pipeline.BlobColumn` em vez do valor,
um defeito da exportação feita pela ANAC. São todas as 258.092 linhas, e
242.726 delas são cópias exatas de outra. O JSON do mesmo mês tem o mesmo
defeito. Em fev/2020, as linhas abertas (o começo do arquivo) estão iguais. Os
dois arquivos têm 88 e 70 MB, contra 11 a 13 MB de um mês normal, e dizem
`Atualizado em: 2021-09-16` e `2021-09-17`.

A [versão descontinuada](https://www.gov.br/anac/pt-br/assuntos/dados-e-estatisticas/historico-de-voos/historico-de-voos-descontinuada)
do histórico de voos, publicada até out/2024, tem os dois meses legíveis, em
outro formato: sem aspas, cabeçalho sem acento (`ICAO Empresa Aerea;Numero
Voo;Codigo DI;...`), datas `dd/mm/aaaa hh:mm` e linhas terminadas só em `\r`.
Usar ou não essa cópia é decisão da etapa 3.

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
| `AEROPORTO_DE_ORIGEM_SIGLA` / `_DESTINO_SIGLA` | Código OACI. Mais nome, UF, região, país e continente |
| `NATUREZA` | `DOMÉSTICA` quando pouso e decolagem são no Brasil e a empresa é brasileira; senão `INTERNACIONAL` |
| `GRUPO_DE_VOO` | `REGULAR`, `NÃO REGULAR` ou `IMPRODUTIVO` |
| `PASSAGEIROS_PAGOS`, `PASSAGEIROS_GRATIS` | Da combinada. Pagos incluem quem viaja com milhas e com promoção |
| `ASSENTOS`, `DECOLAGENS`, `ASK`, `RPK` | Da básica |
| `DISTANCIA_VOADA_KM` | Soma da distância de todas as decolagens. Dividida por `DECOLAGENS`, dá a distância da etapa: 366 km de Congonhas a Santos Dumont, igual ao `km_distancia` da básica |

Grão conferido: nenhuma combinação de empresa, ano, mês, origem, destino,
natureza e grupo de voo se repete nas 1.099.729 linhas. Desde 2019, natureza
doméstica só aparece com empresa brasileira, como diz a definição.

**A distância vem pronta.** A ANAC a calcula "considerando a curvatura do
planeta terra". A haversine da etapa 5 vai ser conferida com ela.

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

A lista de privados tem outro formato: sem coordenadas decimais, e com a
longitude antes da latitude. É por isso que a `dim_aeroporto` (etapa 5) não pode
depender só da lista pública, e o teste "aeroporto sem mercado vira lista, não
some" tem caso real pra pegar.

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
- **VRA:** fev e mar/2020 vêm da cópia descontinuada ou ficam fora? A etapa 3
  decide.
- **Aeródromos:** onde estão `SBFC` e `SBCM`? Não estão nas listas de
  públicos nem de privados, e a de excluídos não tem código OACI pra
  conferir. Sem coordenada, a distância desses pares sai da base estatística.
