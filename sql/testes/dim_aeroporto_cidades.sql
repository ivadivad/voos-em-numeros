-- A cidade de cada aeroporto e a que o mercado usa. Todo aeroporto do
-- mercados.csv (SAO, RIO, BHZ) esta na dimensao com a cidade dele, e so
-- uma vez no CSV; qualquer outro e a propria cidade, com o codigo OACI. E o
-- nome da cidade identifica a cidade: um nome por cidade e uma cidade por
-- nome, ou o nome do mercado seria ambiguo.
SELECT 'aeroporto do mercados.csv fora da cidade dele' AS problema, m.aeroporto_icao AS chave,
       m.mercado || ' esperado, ' || coalesce(d.cidade, 'fora da dimensao') AS detalhe
FROM ref_mercados AS m
LEFT JOIN dim_aeroporto AS d ON d.icao = m.aeroporto_icao
WHERE d.cidade IS DISTINCT FROM m.mercado
UNION ALL
SELECT 'aeroporto repetido no mercados.csv', aeroporto_icao, count(*)::VARCHAR
FROM ref_mercados
GROUP BY aeroporto_icao
HAVING count(*) > 1
UNION ALL
SELECT 'cidade diferente do proprio codigo', d.icao, d.cidade
FROM dim_aeroporto AS d
WHERE d.cidade <> d.icao
  AND NOT EXISTS (SELECT 1 FROM ref_mercados AS m WHERE m.aeroporto_icao = d.icao)
UNION ALL
SELECT 'cidade com mais de um nome', cidade, string_agg(DISTINCT nome_cidade, ' | ')
FROM dim_aeroporto
GROUP BY cidade
HAVING count(DISTINCT nome_cidade) > 1
UNION ALL
SELECT 'nome de mais de uma cidade', nome_cidade, string_agg(DISTINCT cidade, ' | ')
FROM dim_aeroporto
GROUP BY nome_cidade
HAVING count(DISTINCT cidade) > 1 OR nome_cidade IS NULL;
