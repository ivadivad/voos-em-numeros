-- Mart da fusao simulada: um registro por janela e mercado, com a
-- concentracao antes e depois de juntar a Azul e a GOL (o grupo_simulado da
-- dim_grupo) e a leitura do guia do CADE. Vai pra dados/marts/fusao.parquet,
-- que o notebook 04 le pela URL do GitHub.
--
-- Cinco decisoes, todas tomadas antes de rodar:
--
-- 1. Duas janelas de 12 meses. 2024, de jan a dez: os 12 meses antes do
--    memorando entre a Abra e a Azul (15/01/2025), o mercado que a fusao
--    encontraria. E os 12 meses mais recentes da base, contados a partir do
--    ultimo mes publicado: o mercado de hoje. Se a conclusao mudar entre
--    as duas, isso e achado.
--
-- 2. A participacao e a do mart de mercado (decisao do Davi, 17/10/2026):
--    passageiros pagos de voo regular, aqui somados na janela inteira, e nao
--    a media dos meses. Entra o mercado com passageiro regular na janela.
--
-- 3. E uma simulacao estatica: ninguem reage, ninguem entra e ninguem sai.
--    O codeshare entre Azul e GOL (mai/2024 a set/2025) nao muda a conta,
--    porque o passageiro e de quem operou o voo.
--
-- 4. A leitura e a do Guia para Analise de Atos de Concentracao Horizontal
--    do CADE (2016), secao 2.4.2, com as fronteiras do texto: variacao de
--    HHI abaixo de 100 "provavelmente nao geram efeitos competitivos
--    adversos"; HHI depois abaixo de 1.500, mercado nao concentrado; HHI de
--    1.500 a 2.500 com variacao acima de 100, e HHI acima de 2.500 com
--    variacao de 100 a 200, "potencial de gerar preocupacoes
--    concorrenciais"; HHI acima de 2.500 com variacao acima de 200,
--    "presumivelmente geram aumento de poder de mercado". O guia deixa uma
--    brecha, HHI de 1.500 a 2.500 com variacao de exatamente 100, que fica
--    "sem leitura no guia". E o proprio guia avisa que "a 'regra do HHI',
--    como indicativa de nexo causal e uma suposicao inicial, sensivel a
--    outros argumentos": aqui ela e triagem, nao veredito.
--
-- 5. Concorrentes antes e depois com o limite do mart de mercado
--    (limite_concorrente(), 50_mart_mercado.sql).
CREATE OR REPLACE MACRO leitura_cade(hhi_depois, delta) AS
    CASE
        WHEN delta < 100 THEN 'variação pequena'
        WHEN hhi_depois < 1500 THEN 'mercado não concentrado'
        WHEN hhi_depois <= 2500 AND delta > 100 THEN 'potencial preocupação'
        WHEN hhi_depois > 2500 AND delta <= 200 THEN 'potencial preocupação'
        WHEN hhi_depois > 2500 THEN 'presunção de poder de mercado'
        ELSE 'sem leitura no guia'
    END;

CREATE OR REPLACE TABLE mart_fusao AS
WITH janela(janela, inicio, fim) AS (
    SELECT '2024', DATE '2024-01-01', DATE '2024-12-01'
    UNION ALL
    SELECT '12 meses mais recentes', (max(mes) - INTERVAL 11 MONTH)::DATE, max(mes)
    FROM fato_oferta
),
por_grupo AS (
    SELECT j.janela, j.inicio, j.fim, o.mercado, o.grupo, g.grupo_simulado,
           sum(o.passageiros_pagos) AS passageiros
    FROM fato_oferta AS o
    JOIN janela AS j ON o.mes BETWEEN j.inicio AND j.fim
    JOIN dim_grupo AS g USING (grupo)
    WHERE o.grupo_de_voo = 'REGULAR'
    GROUP BY ALL
    HAVING sum(o.passageiros_pagos) > 0
),
por_simulado AS (
    SELECT janela, mercado, grupo_simulado, sum(passageiros) AS passageiros
    FROM por_grupo
    GROUP BY ALL
),
antes AS (
    SELECT
        janela, any_value(inicio) AS inicio, any_value(fim) AS fim, mercado,
        sum(passageiros) AS passageiros,
        coalesce(sum(passageiros) FILTER (WHERE grupo = 'AZUL'), 0) AS azul,
        coalesce(sum(passageiros) FILTER (WHERE grupo = 'GOL'), 0) AS gol,
        sum(passageiros::HUGEINT * passageiros) AS soma_quadrados
    FROM por_grupo
    GROUP BY janela, mercado
),
depois AS (
    SELECT janela, mercado, sum(passageiros::HUGEINT * passageiros) AS soma_quadrados
    FROM por_simulado
    GROUP BY janela, mercado
),
concorrentes AS (
    SELECT a.janela, a.mercado,
           (SELECT count(*) FROM por_grupo AS g
            WHERE g.janela = a.janela AND g.mercado = a.mercado
              AND g.passageiros / a.passageiros >= limite_concorrente()) AS antes,
           (SELECT count(*) FROM por_simulado AS s
            WHERE s.janela = a.janela AND s.mercado = a.mercado
              AND s.passageiros / a.passageiros >= limite_concorrente()) AS depois
    FROM antes AS a
),
hhi AS (
    -- das somas inteiras, numa divisao so (ver 50_mart_mercado.sql)
    SELECT
        a.janela, a.inicio, a.fim, a.mercado, a.passageiros,
        a.azul / a.passageiros AS participacao_azul,
        a.gol / a.passageiros AS participacao_gol,
        10000 * a.soma_quadrados / (a.passageiros::HUGEINT * a.passageiros) AS hhi_antes,
        10000 * d.soma_quadrados / (a.passageiros::HUGEINT * a.passageiros) AS hhi_depois
    FROM antes AS a
    JOIN depois AS d USING (janela, mercado)
)
SELECT
    h.janela,
    h.inicio,
    h.fim,
    h.mercado,
    h.passageiros::BIGINT AS passageiros,
    h.participacao_azul,
    h.participacao_gol,
    c.antes AS concorrentes_antes,
    c.depois AS concorrentes_depois,
    h.hhi_antes,
    h.hhi_depois,
    h.hhi_depois - h.hhi_antes AS delta_hhi,
    leitura_cade(h.hhi_depois, h.hhi_depois - h.hhi_antes) AS leitura
FROM hhi AS h
JOIN concorrentes AS c USING (janela, mercado);

COPY (SELECT * FROM mart_fusao ORDER BY janela, mercado)
TO 'dados/marts/fusao.parquet' (FORMAT parquet);
