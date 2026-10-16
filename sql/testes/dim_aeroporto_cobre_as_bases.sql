-- Todo aeroporto das tres bases esta na dim_aeroporto, uma vez so. Os que
-- nao estao nas listas de aerodromos nao podem sumir: ficam com a cidade da
-- base estatistica, ou so com o codigo, e a coluna cadastro diz qual. Um
-- aeroporto faltando aqui levaria junto, sem erro nenhum, toda linha dos
-- fatos que passa por ele.
WITH nas_bases AS (
    SELECT 'tarifas' AS base, origem AS icao FROM stg_tarifas
    UNION SELECT 'tarifas', destino FROM stg_tarifas
    UNION SELECT 'voos', origem FROM stg_voos
    UNION SELECT 'voos', destino FROM stg_voos
    UNION SELECT 'estatisticas', origem FROM stg_estatisticas
    UNION SELECT 'estatisticas', destino FROM stg_estatisticas
)
SELECT 'fora da dimensao' AS problema, icao, string_agg(base, ', ' ORDER BY base) AS detalhe
FROM nas_bases AS b
WHERE NOT EXISTS (SELECT 1 FROM dim_aeroporto AS d WHERE d.icao = b.icao)
GROUP BY icao
UNION ALL
SELECT 'repetido ou nulo', icao, count(*)::VARCHAR
FROM dim_aeroporto
GROUP BY icao
HAVING count(*) > 1 OR icao IS NULL
UNION ALL
-- cadastro de lista tem que estar na staging dos aerodromos, e o resto nao
SELECT 'cadastro errado', d.icao, d.cadastro
FROM dim_aeroporto AS d
LEFT JOIN stg_aerodromos AS a USING (icao)
WHERE d.cadastro NOT IN ('lista publica', 'lista de privados', 'base estatistica', 'nenhum')
   OR (d.cadastro LIKE 'lista%') <> (a.icao IS NOT NULL)
   OR (d.cadastro = 'base estatistica' AND d.municipio IS NULL)
   OR (d.cadastro = 'nenhum' AND d.municipio IS NOT NULL);
