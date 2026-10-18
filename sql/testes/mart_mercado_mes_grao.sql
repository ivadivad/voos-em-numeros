-- O grao do mart de mercado: um registro por mes, mercado e grupo, sem
-- chave nula e sem registro vazio (sem passageiro, sem fretamento e sem
-- tarifa). Repeticao dobraria os passageiros do grupo e a participacao dele,
-- e o HHI sairia errado sem erro nenhum.
SELECT mes, mercado, grupo, count(*) AS linhas
FROM mart_mercado_mes
GROUP BY mes, mercado, grupo
HAVING count(*) > 1 OR mes IS NULL OR mercado IS NULL OR grupo IS NULL
    OR max(passageiros_pagos + passageiros_nao_regular + assentos_vendidos) = 0;
