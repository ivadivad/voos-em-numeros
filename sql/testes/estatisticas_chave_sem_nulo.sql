-- A chave da base estatistica nao pode ter nulo.
SELECT *
FROM stg_estatisticas
WHERE mes IS NULL OR empresa IS NULL OR origem IS NULL OR destino IS NULL OR grupo_de_voo IS NULL;
