-- A distancia em linha reta (14_distancia.sql) conferida com a que a ANAC
-- publica na base estatistica: distancia voada dividida pelas decolagens, em
-- cada par com voo direto. Na coleta de 13/10/2026, sao 3.522 pares, com
-- diferenca mediana de 0,0% e 95% deles a menos de 0,35%.
--
-- O teste olha o conjunto, nao par a par: cinco pares passam de 5%, todos
-- com SN6L ou entre Sao Jose dos Campos e a Pampulha, e o defeito ali e de
-- coordenada ou da distancia publicada, nao da formula. Formula ou raio
-- errados deslocariam todos os pares juntos.
WITH publicada AS (
    SELECT origem, destino, sum(distancia_voada_km)::DOUBLE / sum(decolagens) AS km_anac, sum(decolagens) AS decolagens
    FROM stg_estatisticas
    WHERE decolagens > 0 AND distancia_voada_km > 0
    GROUP BY origem, destino
),
comparada AS (
    SELECT
        p.decolagens,
        p.km_anac,
        distancia_km(a.latitude, a.longitude, b.latitude, b.longitude) AS km
    FROM publicada AS p
    JOIN stg_aerodromos AS a ON a.icao = p.origem
    JOIN stg_aerodromos AS b ON b.icao = p.destino
    WHERE a.latitude IS NOT NULL AND b.latitude IS NOT NULL
)
SELECT
    count(*) AS pares,
    100 * (sum(km * decolagens) / sum(km_anac * decolagens) - 1) AS diferenca_ponderada_pct,
    100 * quantile_cont(abs(km / km_anac - 1), 0.95) AS p95_diferenca_pct
FROM comparada
HAVING abs(diferenca_ponderada_pct) > 0.5
    OR p95_diferenca_pct > 1
    OR count(*) < 1000;
