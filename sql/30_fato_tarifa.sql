-- Fato das tarifas: um registro por grupo, mercado, mes e valor de tarifa,
-- com os assentos vendidos por esse valor. E o grao das tarifas da ANAC
-- (empresa, origem, destino, mes, tarifa) visto do jeito que a
-- concorrencia e medida: o grupo no lugar da empresa (21_dim_empresa.sql),
-- o par de cidades sem direcao no lugar do par de aeroportos
-- (23_dim_mercado.sql). Valem os tres pontos dos metadados de
-- 10_stg_tarifas.sql: o mes e o da venda, a empresa e a que vendeu, e
-- origem e destino sao os do passageiro.
--
-- Agregar so soma assentos de linhas com o mesmo valor de tarifa, entao a
-- tarifa media de qualquer recorte (soma de tarifa vezes assentos sobre a
-- soma dos assentos) continua a mesma da staging, e um teste confere.
--
-- Fica de fora a venda entre dois aeroportos da mesma cidade, que nao forma
-- mercado: na coleta de 13/10/2026, 14 assentos, todos entre aeroportos de
-- Sao Paulo ou do Rio. O teste de fechamento conta quanto saiu.
--
-- Grupo ou aeroporto que faltar na dimensao nao derruba a linha: ela fica
-- com a chave nula, e o teste de integridade referencial aponta.
CREATE OR REPLACE TABLE fato_tarifa AS
SELECT
    t.mes,
    g.grupo,
    chave_mercado(o.cidade, d.cidade) AS mercado,
    t.tarifa,
    sum(t.assentos)::BIGINT AS assentos
FROM stg_tarifas AS t
LEFT JOIN empresa_grupo AS g ON g.empresa = t.empresa AND no_periodo(t.mes, g.desde, g.ate)
LEFT JOIN dim_aeroporto AS o ON o.icao = t.origem
LEFT JOIN dim_aeroporto AS d ON d.icao = t.destino
WHERE NOT coalesce(o.cidade = d.cidade, false)
GROUP BY ALL;
