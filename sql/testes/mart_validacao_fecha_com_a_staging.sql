-- O mart de validacao junta as tres bases por mes e empresa. Juncao assim
-- pode perder ou repetir linha sem erro nenhum, entao cada total do mart
-- tem que ser o da staging de onde veio. Devolve a medida que nao fecha.
WITH mart AS (
    SELECT
        sum(assentos_vendidos) AS assentos_vendidos,
        sum(receita_tarifas) AS receita_tarifas,
        sum(passageiros_pagos) AS passageiros_pagos,
        sum(decolagens) AS decolagens,
        sum(voos) AS voos,
        sum(voos_realizados) AS voos_realizados
    FROM mart_validacao
),
staging AS (
    SELECT
        (SELECT sum(assentos) FROM stg_tarifas) AS assentos_vendidos,
        (SELECT sum(tarifa * assentos) FROM stg_tarifas)::DOUBLE AS receita_tarifas,
        (SELECT sum(passageiros_pagos) FROM stg_estatisticas) AS passageiros_pagos,
        (SELECT sum(decolagens) FROM stg_estatisticas) AS decolagens,
        (SELECT count(*) FROM stg_voos) AS voos,
        (SELECT count(*) FROM stg_voos WHERE situacao = 'REALIZADO') AS voos_realizados
)
SELECT medida, no_mart, na_staging
FROM (
    SELECT 'assentos_vendidos' AS medida, m.assentos_vendidos::DOUBLE AS no_mart, s.assentos_vendidos::DOUBLE AS na_staging FROM mart AS m, staging AS s
    UNION ALL SELECT 'receita_tarifas', m.receita_tarifas, s.receita_tarifas FROM mart AS m, staging AS s
    UNION ALL SELECT 'passageiros_pagos', m.passageiros_pagos, s.passageiros_pagos FROM mart AS m, staging AS s
    UNION ALL SELECT 'decolagens', m.decolagens, s.decolagens FROM mart AS m, staging AS s
    UNION ALL SELECT 'voos', m.voos, s.voos FROM mart AS m, staging AS s
    UNION ALL SELECT 'voos_realizados', m.voos_realizados, s.voos_realizados FROM mart AS m, staging AS s
)
-- a receita passa por DOUBLE: tolera centavos de arredondamento
WHERE abs(no_mart - na_staging) > 1;
