-- O grao do fato dos voos e o da stg_voos: um registro por voo, que e a
-- empresa, o numero, a origem, o destino e a partida (prevista, ou a real
-- nas etapas nao planejadas). Uma juncao com dimensao repetida duplicaria o
-- voo e o atraso dele, sem erro nenhum.
SELECT empresa, voo, origem, destino, coalesce(partida_prevista, partida_real) AS partida, count(*) AS linhas
FROM fato_voo
GROUP BY empresa, voo, origem, destino, coalesce(partida_prevista, partida_real)
HAVING count(*) > 1;
