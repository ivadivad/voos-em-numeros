-- O projeto e o mercado domestico: todo aeroporto das tres bases tem que
-- ser brasileiro, com codigo OACI comecando com SB, SD, SI, SJ, SN, SS ou SW.
-- A staging dos voos filtra isso; tarifas e base estatistica, nao, entao
-- ali o teste confere o dado como a ANAC publicou.
SELECT base, origem, destino, count(*) AS linhas
FROM (
    SELECT 'tarifas' AS base, origem, destino FROM stg_tarifas
    UNION ALL
    SELECT 'voos', origem, destino FROM stg_voos
    UNION ALL
    SELECT 'estatisticas', origem, destino FROM stg_estatisticas
)
WHERE left(origem, 2) NOT IN ('SB', 'SD', 'SI', 'SJ', 'SN', 'SS', 'SW')
   OR left(destino, 2) NOT IN ('SB', 'SD', 'SI', 'SJ', 'SN', 'SS', 'SW')
GROUP BY ALL;
