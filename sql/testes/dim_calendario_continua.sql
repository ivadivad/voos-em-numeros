-- O calendario e mensal e continuo: um registro por mes, no dia 1, sem
-- buraco entre o primeiro e o ultimo, e todo mes das tres bases esta nele.
-- Buraco quebraria a serie no painel; mes das bases fora do calendario faria
-- o fato daquele mes sumir na juncao com a dimensao, sem erro nenhum.
WITH seguinte AS (
    SELECT mes, lead(mes) OVER (ORDER BY mes) AS proximo
    FROM dim_calendario
),
das_bases AS (
    SELECT DISTINCT mes FROM stg_tarifas
    UNION
    SELECT DISTINCT mes FROM stg_estatisticas
    UNION
    SELECT DISTINCT strptime(left(arquivo, 6), '%Y%m')::DATE FROM stg_voos
)
SELECT 'mes repetido ou nulo' AS problema, mes
FROM dim_calendario
GROUP BY mes
HAVING count(*) > 1 OR mes IS NULL
UNION ALL
SELECT 'mes fora do dia 1', mes
FROM dim_calendario
WHERE day(mes) <> 1
UNION ALL
SELECT 'buraco depois deste mes', mes
FROM seguinte
WHERE proximo <> mes + INTERVAL 1 MONTH
UNION ALL
SELECT 'mes das bases fora do calendario', b.mes
FROM das_bases AS b
WHERE NOT EXISTS (SELECT 1 FROM dim_calendario AS c WHERE c.mes = b.mes);
