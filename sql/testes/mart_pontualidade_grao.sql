-- O grao dos dois marts de pontualidade: um registro por mes, grupo, origem
-- e destino (o mercado sai dos dois aeroportos), e um por mes, grupo, dia
-- da semana e hora. Sem chave nula, sem registro vazio, dia da semana de 1
-- a 7 e hora de 0 a 23. Repeticao dobraria os voos de uma rota ou de uma
-- hora, e o percentual de atraso sairia certo no total e errado no recorte.
SELECT 'rota' AS mart, mes, grupo, origem || '-' || destino AS chave, count(*) AS linhas
FROM mart_pontualidade_rota
GROUP BY mes, grupo, origem, destino
HAVING count(*) > 1 OR mes IS NULL OR grupo IS NULL OR origem IS NULL OR destino IS NULL
    OR max(mercado) IS NULL OR min(voos_previstos) = 0
UNION ALL
SELECT 'horario', mes, grupo, dia_semana || ' ' || hora, count(*)
FROM mart_pontualidade_horario
GROUP BY mes, grupo, dia_semana, hora
HAVING count(*) > 1 OR mes IS NULL OR grupo IS NULL
    OR dia_semana IS NULL OR dia_semana NOT BETWEEN 1 AND 7
    OR hora IS NULL OR hora NOT BETWEEN 0 AND 23
    OR min(voos_previstos) = 0;
