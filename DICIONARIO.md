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

## Perguntas em aberto

- **Tarifas:** o `N` de `Tarifa-N`, no cabeçalho B, quer dizer "nominal"? Os
  metadados dizem que o valor é nominal, mas o cabeçalho não explica.
- **Tarifas:** a ANAC vai renomear o arquivo de mai/2026? Se renomear, o
  coletor precisa achar o mês pelo novo nome sem baixar duas vezes.
