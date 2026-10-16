-- O fato dos voos fecha com a staging, mes a mes: os voos, os realizados,
-- os cancelados e os atrasados mais de 15 minutos do fato, somados aos dos
-- voos entre aeroportos da mesma cidade, que ficam de fora, sao
-- exatamente os da stg_voos.
WITH voo AS (
    SELECT strptime(left(v.arquivo, 6), '%Y%m')::DATE AS mes, v.situacao, v.cancelado, v.atraso_chegada_min,
           o.cidade = d.cidade AS mesma_cidade
    FROM stg_voos AS v
    JOIN dim_aeroporto AS o ON o.icao = v.origem
    JOIN dim_aeroporto AS d ON d.icao = v.destino
),
staging AS (
    SELECT mes,
           count(*) AS voos,
           count(*) FILTER (WHERE situacao = 'REALIZADO') AS realizados,
           count(*) FILTER (WHERE cancelado) AS cancelados,
           count(*) FILTER (WHERE atraso_chegada_min > 15) AS atrasados,
           count(*) FILTER (WHERE mesma_cidade) AS fora
    FROM voo
    GROUP BY mes
),
fato AS (
    SELECT mes,
           count(*) AS voos,
           count(*) FILTER (WHERE situacao = 'REALIZADO') AS realizados,
           count(*) FILTER (WHERE cancelado) AS cancelados,
           count(*) FILTER (WHERE atraso_chegada_min > 15) AS atrasados
    FROM fato_voo
    GROUP BY mes
),
fora AS (
    SELECT mes,
           count(*) FILTER (WHERE situacao = 'REALIZADO') AS realizados,
           count(*) FILTER (WHERE cancelado) AS cancelados,
           count(*) FILTER (WHERE atraso_chegada_min > 15) AS atrasados
    FROM voo
    WHERE mesma_cidade
    GROUP BY mes
)
SELECT s.mes, s.voos, f.voos AS voos_fato, s.fora AS voos_fora,
       s.realizados, f.realizados AS realizados_fato, s.cancelados, f.cancelados AS cancelados_fato,
       s.atrasados, f.atrasados AS atrasados_fato
FROM staging AS s
FULL JOIN fato AS f USING (mes)
LEFT JOIN fora AS x USING (mes)
WHERE s.voos IS DISTINCT FROM f.voos + s.fora
   OR s.realizados IS DISTINCT FROM f.realizados + coalesce(x.realizados, 0)
   OR s.cancelados IS DISTINCT FROM f.cancelados + coalesce(x.cancelados, 0)
   OR s.atrasados IS DISTINCT FROM f.atrasados + coalesce(x.atrasados, 0)
   -- voo da staging sem aeroporto na dimensao some do voo acima: confere
   -- o total direto
   OR (SELECT count(*) FROM voo) <> (SELECT count(*) FROM stg_voos);
