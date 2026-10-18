-- As participacoes dos grupos num mercado, no mes, somam 100%: cada uma e a
-- fatia do grupo nos passageiros regulares do mercado. Soma diferente quer
-- dizer grupo faltando ou repetido, ou denominador errado (contando o
-- fretamento, por exemplo). Cada participacao fica entre 0 e 1, sem nulo.
-- A folga e a do arredondamento em DOUBLE.
SELECT mes, mercado, sum(participacao) AS soma, min(participacao) AS menor, max(participacao) AS maior,
       count(*) AS grupos, count(participacao) AS com_participacao
FROM mart_mercado_mes
GROUP BY mes, mercado
HAVING abs(sum(participacao) - 1) > 1e-9
    OR min(participacao) < 0 OR max(participacao) > 1
    OR count(participacao) < count(*);
