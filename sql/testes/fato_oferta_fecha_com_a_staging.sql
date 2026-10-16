-- O fato da oferta fecha com a staging, por mes e grupo de voo: cada
-- medida do fato, somada a do par de aeroportos da mesma cidade, que fica
-- de fora, e exatamente a da stg_estatisticas. Devolve o mes, o grupo de
-- voo e a medida que nao fecha. Soma nula vira zero dos dois lados, como
-- no fato.
WITH linha AS (
    SELECT e.*, coalesce(o.cidade = d.cidade, false) AS mesma_cidade
    FROM stg_estatisticas AS e
    LEFT JOIN dim_aeroporto AS o ON o.icao = e.origem
    LEFT JOIN dim_aeroporto AS d ON d.icao = e.destino
),
staging AS (
    UNPIVOT (
        SELECT mes, grupo_de_voo, mesma_cidade,
               coalesce(sum(passageiros_pagos), 0) AS passageiros_pagos,
               coalesce(sum(passageiros_gratis), 0) AS passageiros_gratis,
               coalesce(sum(assentos), 0) AS assentos,
               coalesce(sum(decolagens), 0) AS decolagens,
               coalesce(sum(distancia_voada_km), 0) AS distancia_voada_km,
               coalesce(sum(ask), 0) AS ask,
               coalesce(sum(rpk), 0) AS rpk
        FROM linha
        GROUP BY mes, grupo_de_voo, mesma_cidade
    )
    ON passageiros_pagos, passageiros_gratis, assentos, decolagens, distancia_voada_km, ask, rpk
    INTO NAME medida VALUE valor
),
fato AS (
    UNPIVOT (
        SELECT mes, grupo_de_voo,
               sum(passageiros_pagos) AS passageiros_pagos, sum(passageiros_gratis) AS passageiros_gratis,
               sum(assentos) AS assentos, sum(decolagens) AS decolagens,
               sum(distancia_voada_km) AS distancia_voada_km, sum(ask) AS ask, sum(rpk) AS rpk
        FROM fato_oferta
        GROUP BY mes, grupo_de_voo
    )
    ON passageiros_pagos, passageiros_gratis, assentos, decolagens, distancia_voada_km, ask, rpk
    INTO NAME medida VALUE valor
),
comparado AS (
    SELECT mes, grupo_de_voo, medida,
           sum(valor) AS na_staging,
           coalesce(sum(valor) FILTER (WHERE mesma_cidade), 0) AS fora
    FROM staging
    GROUP BY mes, grupo_de_voo, medida
)
SELECT mes, grupo_de_voo, medida, c.na_staging, f.valor AS no_fato, c.fora
FROM comparado AS c
FULL JOIN fato AS f USING (mes, grupo_de_voo, medida)
WHERE coalesce(c.na_staging, 0) <> coalesce(f.valor, 0) + coalesce(c.fora, 0);
