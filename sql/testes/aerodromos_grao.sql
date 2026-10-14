-- Um aerodromo por codigo OACI.
SELECT icao, count(*) AS linhas
FROM stg_aerodromos
GROUP BY icao
HAVING count(*) > 1;
