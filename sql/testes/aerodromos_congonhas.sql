-- Congonhas (SBSP) tem que cair dentro do municipio de Sao Paulo: confere de
-- uma vez o sinal, o hemisferio e a ordem de latitude e longitude. A caixa e
-- a do municipio no OpenStreetMap (relacao 298285,
-- https://www.openstreetmap.org/relation/298285).
SELECT icao, latitude, longitude
FROM stg_aerodromos
WHERE icao = 'SBSP'
  AND NOT coalesce(latitude BETWEEN -24.0079 AND -23.3578 AND longitude BETWEEN -46.8263 AND -46.3651, false)
UNION ALL
SELECT 'SBSP nao esta na staging', NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM stg_aerodromos WHERE icao = 'SBSP');
