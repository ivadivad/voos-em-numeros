-- Uma linha por voo. A staging ja resolve as copias exatas e os registros
-- que se contradizem; se este teste falhar, apareceu repeticao de outro
-- tipo.
SELECT empresa, voo, origem, destino, coalesce(partida_prevista, partida_real) AS partida, count(*) AS linhas
FROM stg_voos
GROUP BY ALL
HAVING count(*) > 1;
