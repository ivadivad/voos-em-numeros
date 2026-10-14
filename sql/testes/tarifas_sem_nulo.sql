-- Nenhuma coluna das tarifas pode ser nula. O bruto nao tem campo vazio,
-- entao nulo aqui e valor que o TRY_CAST nao conseguiu converter.
SELECT *
FROM stg_tarifas
WHERE mes IS NULL OR empresa IS NULL OR origem IS NULL OR destino IS NULL
   OR tarifa IS NULL OR assentos IS NULL OR arquivo IS NULL;
