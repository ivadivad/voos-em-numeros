-- O HHI de um mercado no mes fica entre 10.000/n, com n grupos levando
-- passageiro, todos do mesmo tamanho, e 10.000, um grupo so; o mercado de
-- um grupo so tem exatamente 10.000. E o mesmo em todos os registros do
-- mercado no mes, e bate com a conta pela participacao (10.000 vezes a
-- soma dos quadrados): o mart faz a conta pelas somas inteiras, e as duas
-- tem que dar o mesmo.
WITH mercado AS (
    SELECT mes, mercado,
           count(*) FILTER (WHERE passageiros_pagos > 0) AS n,
           min(hhi) AS hhi,
           max(hhi) AS hhi_maior,
           10000 * sum(participacao * participacao) AS hhi_pela_participacao
    FROM mart_mercado_mes
    GROUP BY mes, mercado
)
SELECT mes, mercado, n, hhi, hhi_maior, hhi_pela_participacao
FROM mercado
WHERE hhi IS NULL
   OR hhi <> hhi_maior
   OR hhi < 10000.0 / n - 1e-6
   OR hhi > 10000 + 1e-6
   OR (n = 1 AND hhi <> 10000)
   OR abs(hhi - hhi_pela_participacao) > 1e-6;
