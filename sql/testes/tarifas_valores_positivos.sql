-- Tarifa e assentos vendidos tem que ser maiores que zero.
SELECT *
FROM stg_tarifas
WHERE tarifa <= 0 OR assentos <= 0;
