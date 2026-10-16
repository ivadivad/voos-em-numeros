-- O grao do fato da oferta: um registro por grupo, mercado, mes e grupo de
-- voo, sem valor negativo. Repeticao contaria passageiros duas vezes na
-- participacao do grupo, e o HHI sairia errado sem erro nenhum.
SELECT mes, grupo, mercado, grupo_de_voo, count(*) AS linhas
FROM fato_oferta
GROUP BY mes, grupo, mercado, grupo_de_voo
HAVING count(*) > 1
    OR min(least(passageiros_pagos, passageiros_gratis, assentos, decolagens, distancia_voada_km, ask, rpk)) < 0;
