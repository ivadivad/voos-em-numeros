-- O mart de mercado fecha com os fatos, mes a mes. Todo passageiro de voo
-- regular esta nele, porque o escopo e justamente o mercado-mes com voo
-- regular. O fretamento, os assentos vendidos e a receita do mart, somados
-- aos dos mercado-meses sem voo regular, que ficam de fora, sao exatamente
-- os do fato_oferta e do fato_tarifa. Juncao entre dois fatos e uma
-- dimensao pode perder ou repetir linha sem erro nenhum.
WITH regular AS (
    SELECT mes, mercado
    FROM fato_oferta
    WHERE grupo_de_voo = 'REGULAR'
    GROUP BY mes, mercado
    HAVING sum(passageiros_pagos) > 0
),
oferta AS (
    SELECT o.mes,
           sum(o.passageiros_pagos) FILTER (WHERE o.grupo_de_voo = 'REGULAR') AS regular,
           sum(o.passageiros_pagos) FILTER (WHERE o.grupo_de_voo = 'NÃO REGULAR') AS nao_regular,
           sum(o.passageiros_pagos) FILTER (WHERE o.grupo_de_voo = 'NÃO REGULAR' AND r.mes IS NULL) AS nao_regular_fora
    FROM fato_oferta AS o
    LEFT JOIN regular AS r USING (mes, mercado)
    GROUP BY o.mes
),
tarifa AS (
    SELECT t.mes,
           sum(t.assentos) AS assentos, sum(t.tarifa * t.assentos) AS receita,
           sum(t.assentos) FILTER (WHERE r.mes IS NULL) AS assentos_fora,
           sum(t.tarifa * t.assentos) FILTER (WHERE r.mes IS NULL) AS receita_fora
    FROM fato_tarifa AS t
    LEFT JOIN regular AS r USING (mes, mercado)
    GROUP BY t.mes
),
mart AS (
    SELECT mes, sum(passageiros_pagos) AS regular, sum(passageiros_nao_regular) AS nao_regular,
           sum(assentos_vendidos) AS assentos, sum(receita) AS receita
    FROM mart_mercado_mes
    GROUP BY mes
)
SELECT mes, o.regular, m.regular AS regular_mart,
       o.nao_regular, m.nao_regular AS nao_regular_mart, o.nao_regular_fora,
       t.assentos, m.assentos AS assentos_mart, t.assentos_fora,
       t.receita, m.receita AS receita_mart, t.receita_fora
FROM oferta AS o
FULL JOIN tarifa AS t USING (mes)
FULL JOIN mart AS m USING (mes)
WHERE o.regular IS DISTINCT FROM m.regular
   OR coalesce(o.nao_regular, 0) <> coalesce(m.nao_regular, 0) + coalesce(o.nao_regular_fora, 0)
   OR t.assentos IS DISTINCT FROM m.assentos + coalesce(t.assentos_fora, 0)
   -- a receita do mart passa por DOUBLE: tolera centavos de arredondamento
   OR abs(t.receita - (m.receita + coalesce(t.receita_fora, 0))) > 1
   OR m.mes IS NULL;
