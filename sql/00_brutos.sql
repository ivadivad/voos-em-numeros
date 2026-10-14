-- Views sobre os arquivos brutos da ANAC, do jeito que chegam: tudo texto.
--
-- Nada aqui converte tipo. Inferencia de tipo funciona ate o dia em que nao
-- funciona: uma tarifa com virgula decimal lida como numero some da media sem
-- erro nenhum. A staging (10_stg_*) converte com TRY_CAST, e um teste conta o
-- que nao converteu.
--
-- As opcoes de leitura de cada base sao as conferidas na etapa 1 e descritas
-- no DICIONARIO.md. Os caminhos sao relativos a raiz do repositorio, de onde
-- o construir.py roda.


-- Tarifas: 92 arquivos com cinco versoes de cabecalho, que se alternam sem
-- ordem. So a ordem das sete colunas e constante, entao a leitura e por
-- posicao: a primeira linha e pulada, seja qual for o nome das colunas, e
-- testes/tarifas_cabecalho.sql confere que cada arquivo tem uma das cinco
-- versoes. O detector automatico do DuckDB fica desligado porque descobre o
-- formato pelo primeiro arquivo e nao aceita as 8 colunas da versao D.
CREATE OR REPLACE VIEW bruto_tarifas AS
WITH arquivo AS (
    SELECT *
    FROM read_csv('dados/brutos/tarifas/*.csv',
        auto_detect = false,
        header = false, skip = 1,
        delim = ';', quote = '"', escape = '"',  -- aspas so na versao D
        encoding = 'latin-1',  -- os dados sao ASCII; acento so em cabecalho
        null_padding = true,   -- 7 colunas, ou 8 na versao D
        columns = {'c1': 'VARCHAR', 'c2': 'VARCHAR', 'c3': 'VARCHAR', 'c4': 'VARCHAR',
                   'c5': 'VARCHAR', 'c6': 'VARCHAR', 'c7': 'VARCHAR', 'c8': 'VARCHAR'},
        filename = true)
)
-- versao D (dez/2021 e abr/2022): uma primeira coluna sem nome numera as
-- linhas e empurra as outras sete uma posicao pra direita
SELECT
    parse_filename(filename) AS arquivo,
    CASE WHEN c8 IS NULL THEN c1 ELSE c2 END AS ano,
    CASE WHEN c8 IS NULL THEN c2 ELSE c3 END AS mes,
    CASE WHEN c8 IS NULL THEN c3 ELSE c4 END AS empresa,
    CASE WHEN c8 IS NULL THEN c4 ELSE c5 END AS origem,
    CASE WHEN c8 IS NULL THEN c5 ELSE c6 END AS destino,
    CASE WHEN c8 IS NULL THEN c6 ELSE c7 END AS tarifa,
    CASE WHEN c8 IS NULL THEN c7 ELSE c8 END AS assentos
FROM arquivo;


-- VRA: 92 arquivos com o mesmo cabecalho, tambem lidos por posicao. Com o
-- detector ligado, so contar as linhas levou 163 s e passou de 7 GB de
-- memoria; desligado, 3 s. O preco e que o nome das colunas deixa de ser
-- conferido na leitura, e quem confere e testes/vra_cabecalho.sql. Ausente
-- vem como o texto "null", tratado na staging.
CREATE OR REPLACE VIEW bruto_vra AS
SELECT parse_filename(filename) AS arquivo, * EXCLUDE (filename)
FROM read_csv('dados/brutos/vra/*.csv',
    auto_detect = false,
    skip = 1, header = true,  -- a primeira linha e "Atualizado em: AAAA-MM-DD"
    delim = ';', quote = '"', escape = '"',
    encoding = 'utf-8',  -- com BOM, que fica na linha pulada
    columns = {'empresa': 'VARCHAR', 'voo': 'VARCHAR', 'di': 'VARCHAR', 'tipo_linha': 'VARCHAR',
               'origem': 'VARCHAR', 'destino': 'VARCHAR',
               'partida_prevista': 'VARCHAR', 'partida_real': 'VARCHAR',
               'chegada_prevista': 'VARCHAR', 'chegada_real': 'VARCHAR',
               'situacao': 'VARCHAR', 'justificativa': 'VARCHAR'},
    filename = true);


-- Dados estatisticos: o acumulado, de 2000 ate o ultimo mes, num arquivo so.
-- So as colunas que o projeto usa (ver DICIONARIO.md).
CREATE OR REPLACE VIEW bruto_estatisticas AS
SELECT
    EMPRESA_SIGLA AS empresa,
    EMPRESA_NOME AS empresa_nome,
    ANO AS ano,
    MES AS mes,
    AEROPORTO_DE_ORIGEM_SIGLA AS origem,
    AEROPORTO_DE_DESTINO_SIGLA AS destino,
    NATUREZA AS natureza,
    GRUPO_DE_VOO AS grupo_de_voo,
    PASSAGEIROS_PAGOS AS passageiros_pagos,
    PASSAGEIROS_GRATIS AS passageiros_gratis,
    ASSENTOS AS assentos,
    DECOLAGENS AS decolagens,
    DISTANCIA_VOADA_KM AS distancia_voada_km,
    ASK AS ask,
    RPK AS rpk
FROM read_csv('dados/brutos/estatisticas/Dados_Estatisticos.csv',
    skip = 1, header = true,  -- "Atualizado em", como no VRA
    delim = ';', quote = '"', escape = '"',
    encoding = 'utf-8',
    all_varchar = true);


-- Aerodromos: a lista publica e a de privados, que tem aeroportos das outras
-- bases. Formatos diferentes, uma view pra cada (ver DICIONARIO.md). Nenhum
-- campo vem entre aspas: as aspas do arquivo sao o simbolo dos segundos nas
-- coordenadas (09°52'06"S), e o leitor nao pode trata-las como delimitador.
CREATE OR REPLACE VIEW bruto_aerodromos_publicos AS
SELECT
    "Código OACI" AS icao,
    "Nome" AS nome,
    "Município" AS municipio,
    "UF" AS uf,
    "Município Servido" AS municipio_servido,
    "UF Servido" AS uf_servido,
    "Latitude" AS latitude_gms,
    "Longitude" AS longitude_gms,
    "LATGEOPOINT" AS latitude,
    "LONGEOPOINT" AS longitude
FROM read_csv('dados/brutos/aerodromos/AerodromosPublicos.csv',
    skip = 1, header = true,
    delim = ';', quote = '', escape = '',
    encoding = 'latin-1',
    all_varchar = true);

CREATE OR REPLACE VIEW bruto_aerodromos_privados AS
SELECT
    "Código OACI" AS icao,
    "Nome" AS nome,
    "Município" AS municipio,
    "UF" AS uf,
    "Latitude" AS latitude_gms,
    "Longitude" AS longitude_gms,
    "LATGEOPOINT" AS latitude,
    "LONGEOPOINT" AS longitude
FROM read_csv('dados/brutos/aerodromos/AerodromosPrivados.csv',
    skip = 1, header = true,
    delim = ';', quote = '', escape = '',
    encoding = 'latin-1',
    all_varchar = true);
