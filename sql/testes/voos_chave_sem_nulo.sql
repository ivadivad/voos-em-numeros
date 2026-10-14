-- O voo e a empresa, o numero, a origem, o destino e a partida (prevista,
-- ou a real nas etapas nao planejadas). Nada disso pode ser nulo, nem a
-- situacao.
SELECT *
FROM stg_voos
WHERE empresa IS NULL OR voo IS NULL OR origem IS NULL OR destino IS NULL
   OR coalesce(partida_prevista, partida_real) IS NULL
   OR situacao IS NULL;
