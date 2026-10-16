-- Mercados: um registro por par de cidades, sem direcao, que aparece em
-- alguma das tres bases, com a distancia. E a unidade em que a
-- concentracao (HHI) e o numero de concorrentes vao ser medidos (ver
-- README, "O que e um mercado").
--
-- Quatro decisoes:
--
-- 1. A chave junta as duas cidades em ordem alfabetica: RIO-SAO serve pra
--    Sao Paulo -> Rio e pra Rio -> Sao Paulo. A macro chave_mercado() e a
--    mesma que os fatos usam.
--
-- 2. Par de aeroportos da mesma cidade nao forma mercado: Guarulhos e
--    Viracopos, e tambem o voo que volta pra onde saiu, com origem igual ao
--    destino. Os fatos tiram as mesmas linhas, e os testes deles contam
--    quanto e.
--
-- 3. A distancia de cada par de aeroportos e a haversine (14_distancia.sql)
--    quando os dois tem coordenada; senao, a que a ANAC publica na base
--    estatistica, distancia voada dividida pelas decolagens, nos pares com
--    voo direto; senao, nenhuma, e a coluna distancia_fonte diz o motivo.
--    Na coleta de 13/10/2026, sao 8.512 mercados com coordenada, 43 com a
--    distancia da ANAC e 428 sem distancia, que somam 0,06% dos assentos
--    vendidos.
--
-- 4. A distancia do mercado e a media das distancias dos pares de
--    aeroportos dele, ponderada pelos assentos vendidos nas tarifas no
--    periodo inteiro. Assim, no periodo, a receita dividida pelos assentos
--    vezes a distancia do mercado da o mesmo yield que a conta par a par da
--    etapa 4: R$ 0,4357/km nos dois jeitos, com 0,0002% de diferenca, do
--    arredondamento. Rio-Sao Paulo vai de 336,8 km (Guarulhos-Galeao) a 406,8 km
--    (Viracopos-Santos Dumont) e fica com 365,9 km. Nos 8 mercados com mais
--    de um par e nenhuma tarifa, e a media simples dos pares.
CREATE OR REPLACE MACRO chave_mercado(cidade1, cidade2) AS
    least(cidade1, cidade2) || '-' || greatest(cidade1, cidade2);

CREATE OR REPLACE TABLE dim_mercado AS
WITH pares AS (
    -- cada par de aeroportos sem direcao, de qualquer das bases, com os
    -- assentos vendidos nas tarifas como peso
    SELECT least(origem, destino) AS aeroporto_1, greatest(origem, destino) AS aeroporto_2,
           sum(assentos) AS assentos
    FROM (
        SELECT origem, destino, assentos FROM stg_tarifas
        UNION ALL
        SELECT origem, destino, 0 FROM stg_voos
        UNION ALL
        SELECT origem, destino, 0 FROM stg_estatisticas
    )
    GROUP BY ALL
),
publicada AS (
    -- somas inteiras antes da divisao: o resultado nao depende da ordem
    SELECT least(origem, destino) AS aeroporto_1, greatest(origem, destino) AS aeroporto_2,
           round(sum(distancia_voada_km) / sum(decolagens), 3)::DECIMAL(9, 3) AS km
    FROM stg_estatisticas
    WHERE decolagens > 0 AND distancia_voada_km > 0
    GROUP BY ALL
),
par AS (
    -- distancia arredondada ao metro, como DECIMAL: a media ponderada soma
    -- sem depender da ordem das parcelas (ver 40_mart_validacao.sql)
    SELECT
        a.cidade AS cidade_1,
        b.cidade AS cidade_2,
        p.assentos,
        coalesce(round(distancia_km(a.latitude, a.longitude, b.latitude, b.longitude), 3)::DECIMAL(9, 3),
                 d.km) AS km,
        CASE WHEN a.latitude IS NOT NULL AND b.latitude IS NOT NULL THEN 'coordenadas'
             WHEN d.km IS NOT NULL THEN 'base estatistica'
        END AS fonte
    FROM pares AS p
    JOIN dim_aeroporto AS a ON a.icao = p.aeroporto_1
    JOIN dim_aeroporto AS b ON b.icao = p.aeroporto_2
    LEFT JOIN publicada AS d USING (aeroporto_1, aeroporto_2)
    WHERE a.cidade <> b.cidade
),
mercado AS (
    SELECT
        least(cidade_1, cidade_2) AS cidade_a,
        greatest(cidade_1, cidade_2) AS cidade_b,
        coalesce(sum(km * assentos) / nullif(sum(assentos) FILTER (WHERE km IS NOT NULL), 0),
                 avg(km)) AS km,
        string_agg(DISTINCT fonte, ' e ' ORDER BY fonte) AS fonte
    FROM par
    GROUP BY ALL
),
nome AS (
    SELECT DISTINCT cidade, nome_cidade FROM dim_aeroporto
)
SELECT
    chave_mercado(m.cidade_a, m.cidade_b) AS mercado,
    m.cidade_a,
    a.nome_cidade AS nome_cidade_a,
    m.cidade_b,
    b.nome_cidade AS nome_cidade_b,
    a.nome_cidade || ' – ' || b.nome_cidade AS nome,
    round(m.km, 1)::DECIMAL(7, 1) AS distancia_km,
    coalesce(m.fonte, 'nenhuma: sem coordenada nem voo direto') AS distancia_fonte
FROM mercado AS m
JOIN nome AS a ON a.cidade = m.cidade_a
JOIN nome AS b ON b.cidade = m.cidade_b;

COPY (SELECT * FROM dim_mercado ORDER BY mercado)
TO 'dados/marts/dim_mercado.parquet' (FORMAT parquet);
