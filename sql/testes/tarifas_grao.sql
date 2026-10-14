-- O grao das tarifas: um valor de tarifa por empresa, origem, destino e mes.
-- Se falhar, o grao nao e o que a etapa 1 viu: voltar pro DICIONARIO.md
-- antes de "corrigir" com DISTINCT.
SELECT mes, empresa, origem, destino, tarifa, count(*) AS linhas
FROM stg_tarifas
GROUP BY ALL
HAVING count(*) > 1;
