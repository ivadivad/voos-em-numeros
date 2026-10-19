-- A fusao simulada junta so a Azul e a GOL. O grupo_simulado e o proprio
-- grupo pra todo mundo, menos os dois, que dividem um grupo simulado que nao
-- e o de mais ninguem e nem o nome de um grupo que ja existe. Um grupo a
-- mais na fusao, ou um dos dois de fora, mudaria o HHI depois da fusao sem
-- erro nenhum.
WITH dupla AS (
    SELECT count(*) AS grupos, count(DISTINCT grupo_simulado) AS simulados, min(grupo_simulado) AS simulado
    FROM dim_grupo
    WHERE grupo IN ('AZUL', 'GOL')
)
SELECT 'Azul e GOL fora do mesmo grupo simulado' AS problema, NULL AS grupo, NULL AS grupo_simulado
FROM dupla
WHERE grupos <> 2 OR simulados <> 1
UNION ALL
SELECT 'grupo simulado da dupla igual a um grupo que existe', grupo, grupo_simulado
FROM dim_grupo
WHERE grupo = (SELECT simulado FROM dupla)
UNION ALL
SELECT 'grupo simulado diferente do proprio grupo', grupo, grupo_simulado
FROM dim_grupo
WHERE grupo NOT IN ('AZUL', 'GOL') AND grupo_simulado IS DISTINCT FROM grupo
UNION ALL
SELECT 'outro grupo dentro da fusao', grupo, grupo_simulado
FROM dim_grupo
WHERE grupo NOT IN ('AZUL', 'GOL') AND grupo_simulado = (SELECT simulado FROM dupla);
