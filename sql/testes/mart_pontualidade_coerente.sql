-- As contagens de cada registro dos marts de pontualidade se encaixam:
-- os previstos sao os realizados, os cancelados e os nao informados; o
-- atraso medido cabe nos realizados; cada corte de atraso cabe no anterior
-- (60 no de 30, 30 no de 15, 15 nos medidos); os que chegaram 23 h depois
-- estao no corte de 60, e os que chegaram 2 h antes, fora do de 15. O
-- notebook tira percentuais dessas razoes: um corte maior que o anterior
-- daria mais atraso acima de 60 minutos que acima de 15.
WITH contagens AS (
    SELECT 'rota' AS mart, mes, grupo, origem || '-' || destino AS chave, voos_previstos, voos_realizados,
           voos_cancelados, voos_nao_informados, voos_medidos, voos_atraso_15, voos_atraso_30,
           voos_atraso_60, voos_adiantados_2h, voos_atraso_23h
    FROM mart_pontualidade_rota
    UNION ALL
    SELECT 'horario', mes, grupo, dia_semana || ' ' || hora, voos_previstos, voos_realizados,
           voos_cancelados, voos_nao_informados, voos_medidos, voos_atraso_15, voos_atraso_30,
           voos_atraso_60, voos_adiantados_2h, voos_atraso_23h
    FROM mart_pontualidade_horario
)
SELECT mart, mes, grupo, chave
FROM contagens
WHERE voos_previstos <> voos_realizados + voos_cancelados + voos_nao_informados
   OR voos_medidos > voos_realizados
   OR voos_atraso_15 > voos_medidos
   OR voos_atraso_30 > voos_atraso_15
   OR voos_atraso_60 > voos_atraso_30
   OR voos_atraso_23h > voos_atraso_60
   OR voos_adiantados_2h + voos_atraso_15 > voos_medidos;
