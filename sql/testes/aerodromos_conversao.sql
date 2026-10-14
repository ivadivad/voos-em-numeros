-- A conversao do grau, minuto e segundo (13_stg_aerodromos.sql), conferida
-- com o decimal que a ANAC publica no mesmo arquivo. O decimal descarta a
-- fracao de segundo, entao a diferenca pode chegar a 1"; mais que isso e
-- conversao errada. Tambem aponta coordenada nula quando a publicada cai no
-- Brasil (o grau, minuto e segundo nao foi lido) e UF que nao virou sigla.
WITH publicado AS (
    SELECT
        upper(trim(icao)) AS icao,
        TRY_CAST(latitude AS DOUBLE) AS latitude,
        TRY_CAST(longitude AS DOUBLE) AS longitude,
        coalesce(uf_servido, uf) IS NOT NULL AS tem_uf
    FROM bruto_aerodromos_publicos
    UNION ALL
    SELECT
        upper(trim(icao)),
        TRY_CAST(replace(latitude, ',', '.') AS DOUBLE),
        TRY_CAST(replace(longitude, ',', '.') AS DOUBLE),
        uf IS NOT NULL
    FROM bruto_aerodromos_privados
)
SELECT
    s.icao, s.latitude, s.longitude, s.uf,
    p.latitude AS latitude_publicada, p.longitude AS longitude_publicada
FROM stg_aerodromos AS s
JOIN publicado AS p USING (icao)
WHERE abs(s.latitude - p.latitude) > 1.01 / 3600
   OR abs(s.longitude - p.longitude) > 1.01 / 3600
   OR (s.latitude IS NULL AND p.latitude BETWEEN -34 AND 6 AND p.longitude BETWEEN -74 AND -28)
   OR (s.uf IS NULL AND p.tem_uf);
