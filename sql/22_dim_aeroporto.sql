-- Aeroportos: um registro por codigo OACI que aparece em alguma das tres
-- bases, com nome, municipio, UF, coordenadas e a cidade do mercado.
--
-- Tres decisoes:
--
-- 1. A dimensao cobre os aeroportos das bases, nao os 4.391 aerodromos das
--    listas da ANAC: sao 306 codigos, e 288 estao nas listas (248 na
--    publica, 40 na de privados). Os 18 restantes nao somem. Catorze ficam
--    com a cidade e a UF que a base estatistica da a eles; os outros quatro
--    (SBFC, SBFE, SBGU e SNOB), que so aparecem nas tarifas ou no VRA,
--    ficam so com o codigo. A coluna cadastro diz de onde veio cada um, e os
--    18 sem coordenada sao os que pedem distancia de outra fonte
--    (23_dim_mercado.sql).
--
-- 2. A cidade do mercado e o codigo IATA da area metropolitana, pela tabela
--    dados/referencia/mercados.csv: SAO, RIO e BHZ. Qualquer outro aeroporto
--    e a propria cidade, com o codigo OACI (ver README, "O que e um
--    mercado").
--
-- 3. O nome da cidade e o do mercados.csv ou o municipio, do jeito que a
--    fonte publica (a lista de privados e a base estatistica escrevem em
--    maiusculas). Na coleta de 13/10/2026, 23 nomes se repetiriam entre
--    cidades diferentes (Curitiba e o Afonso Pena e o Bacacheri; Sao Paulo e
--    SAO e o Campo de Marte), e nesses as 45 cidades que nao sao do
--    mercados.csv levam o codigo: "Curitiba (SBBI)". Assim o nome do
--    mercado nunca e ambiguo.
CREATE OR REPLACE VIEW ref_mercados AS
SELECT *
FROM read_csv('dados/referencia/mercados.csv', header = true, all_varchar = true);

CREATE OR REPLACE TABLE dim_aeroporto AS
WITH nas_bases AS (
    SELECT origem AS icao FROM stg_tarifas
    UNION SELECT destino FROM stg_tarifas
    UNION SELECT origem FROM stg_voos
    UNION SELECT destino FROM stg_voos
    UNION SELECT origem FROM stg_estatisticas
    UNION SELECT destino FROM stg_estatisticas
),
estatistica AS (
    -- todo o acumulado, nao so o periodo do projeto: e cadastro, nao dado.
    -- Cada um dos 14 tem uma cidade e uma UF so; o min deixa o resultado
    -- igual de uma rodada pra outra se isso mudar
    SELECT icao, min(cidade) AS municipio, min(uf) AS uf
    FROM (
        SELECT upper(trim(origem)) AS icao, trim(origem_nome) AS cidade, trim(origem_uf) AS uf
        FROM bruto_estatisticas
        UNION ALL
        SELECT upper(trim(destino)), trim(destino_nome), trim(destino_uf)
        FROM bruto_estatisticas
    )
    WHERE cidade IS NOT NULL
    GROUP BY icao
),
aeroporto AS (
    SELECT
        b.icao,
        a.nome,
        coalesce(a.municipio, e.municipio) AS municipio,
        coalesce(a.uf, e.uf) AS uf,
        a.latitude,
        a.longitude,
        coalesce(m.mercado, b.icao) AS cidade,
        coalesce(m.nome_mercado, a.municipio, e.municipio, b.icao) AS nome_base,
        m.nome_mercado IS NOT NULL AS no_mercados_csv,
        CASE
            WHEN a.lista = 'publica' THEN 'lista publica'
            WHEN a.lista = 'privada' THEN 'lista de privados'
            WHEN e.municipio IS NOT NULL THEN 'base estatistica'
            ELSE 'nenhum'
        END AS cadastro
    FROM nas_bases AS b
    LEFT JOIN stg_aerodromos AS a USING (icao)
    LEFT JOIN estatistica AS e USING (icao)
    LEFT JOIN ref_mercados AS m ON m.aeroporto_icao = b.icao
),
nomes AS (
    SELECT lower(nome_base) AS chave, count(DISTINCT cidade) AS cidades
    FROM aeroporto
    GROUP BY lower(nome_base)
)
SELECT
    a.icao,
    a.nome,
    a.municipio,
    a.uf,
    a.latitude,
    a.longitude,
    a.cidade,
    CASE WHEN n.cidades > 1 AND NOT a.no_mercados_csv THEN a.nome_base || ' (' || a.icao || ')'
         ELSE a.nome_base
    END AS nome_cidade,
    a.cadastro
FROM aeroporto AS a
JOIN nomes AS n ON n.chave = lower(a.nome_base);

COPY (SELECT * FROM dim_aeroporto ORDER BY icao)
TO 'dados/marts/dim_aeroporto.parquet' (FORMAT parquet);
