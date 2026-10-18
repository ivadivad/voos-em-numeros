-- A tarifa por km sai da razao das somas: a receita somada dividida pelos
-- assentos-km somados, como o yield da etapa 4. Pra isso valer em qualquer
-- recorte, os assentos-km do mart tem que ser os assentos vendidos vezes a
-- distancia do mercado, e mercado sem distancia tem que ficar com
-- assentos-km nulo, e nao zero: zero entraria na soma e puxaria a tarifa
-- por km pra cima. Confere as duas coisas registro a registro, e que a soma
-- do mes fecha com o fato_tarifa no mesmo escopo.
WITH escopo AS (
    SELECT DISTINCT mes, mercado FROM mart_mercado_mes
),
fato AS (
    SELECT t.mes, sum(t.assentos * m.distancia_km)::DOUBLE AS assentos_km
    FROM fato_tarifa AS t
    JOIN escopo USING (mes, mercado)
    JOIN dim_mercado AS m USING (mercado)
    GROUP BY t.mes
),
mart AS (
    SELECT mes, sum(assentos_km) AS assentos_km
    FROM mart_mercado_mes
    GROUP BY mes
)
SELECT 'assentos-km nulo sem motivo, ou presente sem distancia' AS problema, a.mes, a.mercado, a.grupo,
       a.assentos_km AS valor
FROM mart_mercado_mes AS a
JOIN dim_mercado AS m USING (mercado)
WHERE (a.assentos_km IS NULL) <> (m.distancia_km IS NULL)
UNION ALL
SELECT 'assentos-km diferente de assentos vezes a distancia', a.mes, a.mercado, a.grupo, a.assentos_km
FROM mart_mercado_mes AS a
JOIN dim_mercado AS m USING (mercado)
WHERE abs(a.assentos_km - a.assentos_vendidos * m.distancia_km) > 1e-6 * greatest(a.assentos_km, 1)
UNION ALL
SELECT 'soma do mes diferente do fato', mes, NULL, NULL, m.assentos_km
FROM fato AS f
FULL JOIN mart AS m USING (mes)
WHERE abs(f.assentos_km - m.assentos_km) > 1e-9 * f.assentos_km
   OR f.assentos_km IS NULL OR m.assentos_km IS NULL;
