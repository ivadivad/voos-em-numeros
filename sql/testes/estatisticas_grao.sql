-- O grao da base estatistica: empresa, mes, par de aerodromos e grupo de
-- voo (a natureza ja foi filtrada na staging).
SELECT mes, empresa, origem, destino, grupo_de_voo, count(*) AS linhas
FROM stg_estatisticas
GROUP BY ALL
HAVING count(*) > 1;
