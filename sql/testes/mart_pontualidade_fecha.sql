-- Os dois marts de pontualidade fecham com o fato dos voos, mes a mes e
-- grupo a grupo, nas dez contagens: recontadas aqui direto do fato_voo, sem
-- passar pela view do mart. E o que fica de fora sao so as etapas nao
-- planejadas, sem partida prevista e todas realizadas: 13.749 voos na
-- coleta de 13/10/2026.
WITH fato AS (
    SELECT mes, grupo, [
        count(*),
        count(*) FILTER (WHERE situacao = 'REALIZADO'),
        count(*) FILTER (WHERE situacao = 'CANCELADO'),
        count(*) FILTER (WHERE situacao = 'NÃO INFORMADO'),
        count(*) FILTER (WHERE situacao = 'REALIZADO' AND atraso_chegada_min IS NOT NULL),
        count(*) FILTER (WHERE atraso_chegada_min > 15),
        count(*) FILTER (WHERE atraso_chegada_min > 30),
        count(*) FILTER (WHERE atraso_chegada_min > 60),
        count(*) FILTER (WHERE atraso_chegada_min <= -120),
        count(*) FILTER (WHERE atraso_chegada_min >= 1380)
    ]::BIGINT[] AS contagens
    FROM fato_voo
    WHERE partida_prevista IS NOT NULL
    GROUP BY mes, grupo
),
rota AS (
    SELECT mes, grupo, [
        sum(voos_previstos), sum(voos_realizados), sum(voos_cancelados), sum(voos_nao_informados),
        sum(voos_medidos), sum(voos_atraso_15), sum(voos_atraso_30), sum(voos_atraso_60),
        sum(voos_adiantados_2h), sum(voos_atraso_23h)
    ]::BIGINT[] AS contagens
    FROM mart_pontualidade_rota
    GROUP BY mes, grupo
),
horario AS (
    SELECT mes, grupo, [
        sum(voos_previstos), sum(voos_realizados), sum(voos_cancelados), sum(voos_nao_informados),
        sum(voos_medidos), sum(voos_atraso_15), sum(voos_atraso_30), sum(voos_atraso_60),
        sum(voos_adiantados_2h), sum(voos_atraso_23h)
    ]::BIGINT[] AS contagens
    FROM mart_pontualidade_horario
    GROUP BY mes, grupo
)
SELECT 'rota' AS mart, coalesce(f.mes, r.mes) AS mes, coalesce(f.grupo, r.grupo) AS grupo,
       r.contagens::VARCHAR AS no_mart, f.contagens::VARCHAR AS no_fato
FROM fato AS f
FULL JOIN rota AS r ON r.mes = f.mes AND r.grupo = f.grupo
WHERE r.contagens IS DISTINCT FROM f.contagens
UNION ALL
SELECT 'horario', coalesce(f.mes, h.mes), coalesce(f.grupo, h.grupo), h.contagens::VARCHAR, f.contagens::VARCHAR
FROM fato AS f
FULL JOIN horario AS h ON h.mes = f.mes AND h.grupo = f.grupo
WHERE h.contagens IS DISTINCT FROM f.contagens
UNION ALL
SELECT 'fora dos marts', NULL, NULL,
       count(*) || ' sem partida prevista, ' || count(*) FILTER (WHERE situacao <> 'REALIZADO') || ' nao realizados',
       'so realizados'
FROM fato_voo
WHERE partida_prevista IS NULL
HAVING count(*) FILTER (WHERE situacao <> 'REALIZADO') > 0;
