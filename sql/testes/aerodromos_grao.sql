-- Um aerodromo por codigo OACI, e nenhum codigo vazio.
SELECT icao, count(*) AS linhas
FROM stg_aerodromos
GROUP BY icao
HAVING count(*) > 1 OR icao IS NULL OR icao = '';
