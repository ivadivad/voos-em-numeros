-- Todo mercado tem distancia, ou o motivo de nao ter. E a distancia de um
-- mercado com coordenada e uma media das distancias entre os aeroportos
-- das duas cidades: tem que cair entre a menor e a maior delas. Peso
-- trocado ou soma no lugar da media a jogariam pra fora; um par de
-- aeroportos solto num mercado errado, tambem.
WITH faixa AS (
    -- todas as combinacoes de aeroportos das duas cidades, voadas ou nao
    SELECT m.mercado,
           min(distancia_km(a.latitude, a.longitude, b.latitude, b.longitude)) AS menor,
           max(distancia_km(a.latitude, a.longitude, b.latitude, b.longitude)) AS maior
    FROM dim_mercado AS m
    JOIN dim_aeroporto AS a ON a.cidade = m.cidade_a
    JOIN dim_aeroporto AS b ON b.cidade = m.cidade_b
    WHERE m.distancia_fonte = 'coordenadas'
    GROUP BY m.mercado
)
SELECT 'sem distancia e sem motivo, ou com os dois' AS problema, mercado, distancia_fonte AS detalhe
FROM dim_mercado
WHERE (distancia_km IS NULL) <> (distancia_fonte = 'nenhuma: sem coordenada nem voo direto')
   OR distancia_fonte IS NULL
   OR distancia_fonte NOT IN ('coordenadas', 'base estatistica', 'base estatistica e coordenadas',
                              'nenhuma: sem coordenada nem voo direto')
UNION ALL
SELECT 'distancia nao positiva', mercado, distancia_km::VARCHAR
FROM dim_mercado
WHERE distancia_km <= 0
UNION ALL
-- a distancia e arredondada duas vezes, ao metro em cada par e a 0,1 km no
-- mercado: a folga e a soma das duas metades
SELECT 'fora da faixa dos aeroportos das duas cidades', f.mercado,
       m.distancia_km || ' km, entre ' || round(f.menor, 3) || ' e ' || round(f.maior, 3)
FROM faixa AS f
JOIN dim_mercado AS m USING (mercado)
WHERE m.distancia_km NOT BETWEEN f.menor - 0.0505 AND f.maior + 0.0505;
