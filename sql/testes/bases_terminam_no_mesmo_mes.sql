-- As tres bases mensais terminam no mesmo mes, e o calendario, os fatos e
-- os marts terminam nele. A ANAC publica cada base num dia diferente (as
-- tarifas de 15 a 28 dias depois do fim do mes, a base estatistica perto do
-- dia 14, o VRA perto do dia 28), e numa coleta feita no meio do mes uma
-- base chega um mes na frente das outras: em 22/10/2026, as tarifas de
-- set/2026 ja tinham saido, e o VRA de set/2026 nao. Sem o corte de
-- 15_ultimo_mes_comum.sql, esse mes entrava nos marts pela metade (com
-- tarifa e sem voo), e a janela dos 12 meses mais recentes andava um mes so
-- de um lado. Devolve o que termina fora do ultimo mes do calendario.
WITH ultimos(objeto, ultimo) AS (
    SELECT 'stg_tarifas', max(mes) FROM stg_tarifas
    UNION ALL SELECT 'stg_estatisticas', max(mes) FROM stg_estatisticas
    UNION ALL SELECT 'stg_voos', strptime(left(max(arquivo), 6), '%Y%m')::DATE FROM stg_voos
    UNION ALL SELECT 'fato_tarifa', max(mes) FROM fato_tarifa
    UNION ALL SELECT 'fato_voo', max(mes) FROM fato_voo
    UNION ALL SELECT 'fato_oferta', max(mes) FROM fato_oferta
    UNION ALL SELECT 'mart_validacao', max(mes) FROM mart_validacao
    UNION ALL SELECT 'mart_mercado_mes', max(mes) FROM mart_mercado_mes
    UNION ALL SELECT 'mart_fusao', max(fim) FROM mart_fusao
    UNION ALL SELECT 'mart_pontualidade_rota', max(mes) FROM mart_pontualidade_rota
    UNION ALL SELECT 'mart_pontualidade_horario', max(mes) FROM mart_pontualidade_horario
)
SELECT objeto, ultimo, (SELECT max(mes) FROM dim_calendario) AS fim_do_calendario
FROM ultimos
WHERE ultimo IS DISTINCT FROM (SELECT max(mes) FROM dim_calendario);
