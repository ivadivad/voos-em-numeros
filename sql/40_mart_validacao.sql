-- Mart de validacao: os totais que a ANAC publica, pra conferir a base
-- contra os numeros oficiais no notebook 01-validacao. Vai pra
-- dados/marts/validacao.parquet, versionado, que o notebook le pela URL
-- bruta do GitHub, sem rodar a coleta.
--
-- Um registro por mes e empresa, e nao por ano: a ANAC publica a tarifa
-- media mes a mes e por empresa, e o ano sai da soma dos meses. So entram
-- somas e contagens, nenhuma media: tarifa media e yield saem da razao entre
-- as somas, e assim a media de um ano ou de um grupo de empresas fica
-- ponderada pelos assentos, como a ANAC calcula.
--
-- A mesma empresa quer dizer coisas diferentes em cada base (ver
-- DICIONARIO.md):
-- - tarifas: a empresa que vendeu, no mes da venda;
-- - base estatistica e VRA: a empresa que operou, no mes do voo. No VRA, o
--   mes e o do arquivo, que e como a ANAC agrupa os voos.
-- Empresa ausente numa base, no mes, fica com zero nas colunas dela.
CREATE OR REPLACE TABLE mart_validacao AS
WITH distancias AS (
    -- uma conta por par, nao por linha; sem coordenada numa ponta, fica nula.
    -- Arredondada ao metro, como DECIMAL: somada em DOUBLE, em paralelo, a
    -- ordem das parcelas mudava o ultimo digito de uma rodada pra outra, e o
    -- parquet saia diferente sem dado novo
    SELECT
        p.origem,
        p.destino,
        round(distancia_km(a.latitude, a.longitude, b.latitude, b.longitude), 3)::DECIMAL(9, 3) AS km
    FROM (SELECT DISTINCT origem, destino FROM stg_tarifas) AS p
    LEFT JOIN stg_aerodromos AS a ON a.icao = p.origem
    LEFT JOIN stg_aerodromos AS b ON b.icao = p.destino
),
tarifas AS (
    SELECT
        t.mes,
        t.empresa,
        sum(t.assentos) AS assentos_vendidos,
        sum(t.tarifa * t.assentos) AS receita_tarifas,
        -- faixas como a ANAC conta: "abaixo de R$ 500" inclui os R$ 500
        sum(t.assentos) FILTER (WHERE t.tarifa <= 300) AS assentos_ate_300,
        sum(t.assentos) FILTER (WHERE t.tarifa <= 500) AS assentos_ate_500,
        sum(t.assentos) FILTER (WHERE t.tarifa > 1500) AS assentos_acima_1500,
        -- yield: so o que tem distancia conhecida, no numerador e no denominador
        sum(t.tarifa * t.assentos) FILTER (WHERE d.km > 0) AS receita_com_distancia,
        sum(d.km * t.assentos) FILTER (WHERE d.km > 0) AS assentos_km
    FROM stg_tarifas AS t
    LEFT JOIN distancias AS d ON d.origem = t.origem AND d.destino = t.destino
    GROUP BY t.mes, t.empresa
),
estatisticas AS (
    SELECT
        mes,
        empresa,
        sum(passageiros_pagos) AS passageiros_pagos,
        sum(passageiros_pagos) FILTER (WHERE grupo_de_voo = 'REGULAR') AS passageiros_pagos_regular,
        sum(decolagens) AS decolagens,
        sum(rpk) AS rpk,
        sum(ask) AS ask
    FROM stg_estatisticas
    GROUP BY mes, empresa
),
voos AS (
    SELECT
        strptime(left(arquivo, 6), '%Y%m')::DATE AS mes,
        empresa,
        count(*) AS voos,
        count(*) FILTER (WHERE situacao = 'REALIZADO') AS voos_realizados,
        count(*) FILTER (WHERE cancelado) AS voos_cancelados,
        count(*) FILTER (WHERE atraso_chegada_min > 15) AS voos_atraso_15,
        count(*) FILTER (WHERE atraso_chegada_min > 30) AS voos_atraso_30,
        count(*) FILTER (WHERE atraso_chegada_min > 60) AS voos_atraso_60
    FROM stg_voos
    GROUP BY ALL
),
chaves AS (
    SELECT mes, empresa FROM tarifas
    UNION
    SELECT mes, empresa FROM estatisticas
    UNION
    SELECT mes, empresa FROM voos
)
SELECT
    c.mes,
    c.empresa,
    -- tarifas
    coalesce(t.assentos_vendidos, 0)::BIGINT AS assentos_vendidos,
    coalesce(t.receita_tarifas, 0)::DOUBLE AS receita_tarifas,
    coalesce(t.assentos_ate_300, 0)::BIGINT AS assentos_ate_300,
    coalesce(t.assentos_ate_500, 0)::BIGINT AS assentos_ate_500,
    coalesce(t.assentos_acima_1500, 0)::BIGINT AS assentos_acima_1500,
    coalesce(t.receita_com_distancia, 0)::DOUBLE AS receita_com_distancia,
    coalesce(t.assentos_km, 0)::DOUBLE AS assentos_km,
    -- base estatistica
    coalesce(e.passageiros_pagos, 0)::BIGINT AS passageiros_pagos,
    coalesce(e.passageiros_pagos_regular, 0)::BIGINT AS passageiros_pagos_regular,
    coalesce(e.decolagens, 0)::BIGINT AS decolagens,
    coalesce(e.rpk, 0)::BIGINT AS rpk,
    coalesce(e.ask, 0)::BIGINT AS ask,
    -- VRA
    coalesce(v.voos, 0)::BIGINT AS voos,
    coalesce(v.voos_realizados, 0)::BIGINT AS voos_realizados,
    coalesce(v.voos_cancelados, 0)::BIGINT AS voos_cancelados,
    coalesce(v.voos_atraso_15, 0)::BIGINT AS voos_atraso_15,
    coalesce(v.voos_atraso_30, 0)::BIGINT AS voos_atraso_30,
    coalesce(v.voos_atraso_60, 0)::BIGINT AS voos_atraso_60
FROM chaves AS c
LEFT JOIN tarifas AS t USING (mes, empresa)
LEFT JOIN estatisticas AS e USING (mes, empresa)
LEFT JOIN voos AS v USING (mes, empresa);

-- ordenado, pra rodar de novo sem dado novo dar o mesmo arquivo, byte a byte
COPY (SELECT * FROM mart_validacao ORDER BY mes, empresa)
TO 'dados/marts/validacao.parquet' (FORMAT parquet);
