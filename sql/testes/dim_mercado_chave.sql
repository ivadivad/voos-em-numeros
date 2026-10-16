-- A chave do mercado e o par de cidades sem direcao: as duas cidades em
-- ordem alfabetica, nunca a mesma dos dois lados, um registro por par. E
-- todo par de aeroportos das tres bases em cidades diferentes tem o seu
-- mercado: um par faltando faria as linhas dele sumirem dos fatos.
WITH pares AS (
    SELECT DISTINCT origem, destino FROM stg_tarifas
    UNION
    SELECT DISTINCT origem, destino FROM stg_voos
    UNION
    SELECT DISTINCT origem, destino FROM stg_estatisticas
)
SELECT 'mercado repetido ou nulo' AS problema, mercado, count(*)::VARCHAR AS detalhe
FROM dim_mercado
GROUP BY mercado
HAVING count(*) > 1 OR mercado IS NULL
UNION ALL
SELECT 'chave com direcao ou com a mesma cidade', mercado, cidade_a || ' / ' || cidade_b
FROM dim_mercado
WHERE NOT cidade_a < cidade_b
   OR mercado <> cidade_a || '-' || cidade_b
UNION ALL
SELECT 'cidade fora da dim_aeroporto ou sem nome', mercado, nome
FROM dim_mercado AS m
WHERE nome IS NULL
   OR NOT EXISTS (SELECT 1 FROM dim_aeroporto AS a WHERE a.cidade = m.cidade_a AND a.nome_cidade = m.nome_cidade_a)
   OR NOT EXISTS (SELECT 1 FROM dim_aeroporto AS a WHERE a.cidade = m.cidade_b AND a.nome_cidade = m.nome_cidade_b)
UNION ALL
SELECT 'par das bases sem mercado', chave_mercado(o.cidade, d.cidade), p.origem || '-' || p.destino
FROM pares AS p
JOIN dim_aeroporto AS o ON o.icao = p.origem
JOIN dim_aeroporto AS d ON d.icao = p.destino
WHERE o.cidade <> d.cidade
  AND NOT EXISTS (SELECT 1 FROM dim_mercado AS m WHERE m.mercado = chave_mercado(o.cidade, d.cidade));
