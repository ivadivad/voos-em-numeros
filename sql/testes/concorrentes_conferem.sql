-- O numero de concorrentes e o de grupos com participacao de pelo menos
-- limite_concorrente(), a macro de 50_mart_mercado.sql, e e o mesmo em
-- todos os registros do mercado no mes. O teste reconta pela macro: um
-- limite escrito direto no mart, diferente dela, aparece aqui. Fica entre 1
-- e o numero de grupos com passageiro: com menos de 20 grupos no mercado, o
-- maior sempre passa de 5%.
WITH mercado AS (
    SELECT mes, mercado,
           min(concorrentes) AS concorrentes,
           max(concorrentes) AS concorrentes_maior,
           count(*) FILTER (WHERE participacao >= limite_concorrente()) AS recontados,
           count(*) FILTER (WHERE passageiros_pagos > 0) AS grupos_com_passageiro
    FROM mart_mercado_mes
    GROUP BY mes, mercado
)
SELECT *
FROM mercado
WHERE concorrentes IS NULL
   OR concorrentes <> concorrentes_maior
   OR concorrentes <> recontados
   OR concorrentes NOT BETWEEN 1 AND grupos_com_passageiro;
