-- O fato das tarifas fecha com a staging: os assentos e a receita (tarifa
-- vezes assentos) do fato, somados aos da venda entre aeroportos da mesma
-- cidade, que nao forma mercado e fica de fora, sao exatamente os da
-- stg_tarifas, mes a mes. Juncao com as dimensoes pode perder ou repetir
-- linha sem erro nenhum; a soma em DECIMAL e exata, sem folga.
WITH fato AS (
    SELECT mes, sum(assentos) AS assentos, sum(tarifa * assentos) AS receita
    FROM fato_tarifa
    GROUP BY mes
),
fora AS (
    SELECT t.mes, sum(t.assentos) AS assentos, sum(t.tarifa * t.assentos) AS receita
    FROM stg_tarifas AS t
    JOIN dim_aeroporto AS o ON o.icao = t.origem
    JOIN dim_aeroporto AS d ON d.icao = t.destino
    WHERE o.cidade = d.cidade
    GROUP BY t.mes
),
staging AS (
    SELECT mes, sum(assentos) AS assentos, sum(tarifa * assentos) AS receita
    FROM stg_tarifas
    GROUP BY mes
)
SELECT
    s.mes,
    s.assentos AS assentos_staging,
    f.assentos AS assentos_fato,
    coalesce(x.assentos, 0) AS assentos_fora,
    s.receita AS receita_staging,
    f.receita AS receita_fato,
    coalesce(x.receita, 0) AS receita_fora
FROM staging AS s
FULL JOIN fato AS f USING (mes)
LEFT JOIN fora AS x USING (mes)
WHERE s.assentos IS DISTINCT FROM f.assentos + coalesce(x.assentos, 0)
   OR s.receita IS DISTINCT FROM f.receita + coalesce(x.receita, 0);
