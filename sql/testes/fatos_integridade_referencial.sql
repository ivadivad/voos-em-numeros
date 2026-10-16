-- Toda chave dos tres fatos existe na dimensao dela, e nenhuma e nula: o
-- mes no calendario, o grupo na dim_grupo, o mercado na dim_mercado e, no
-- fato dos voos, a empresa na dim_empresa e os dois aeroportos na
-- dim_aeroporto. Os fatos guardam a linha com chave nula em vez de
-- descarta-la, e e aqui que ela aparece. Chave orfa faria a linha sumir de
-- qualquer recorte por aquela dimensao, no painel e nos marts.
--
-- Confere as chaves distintas, nao as linhas: o fato das tarifas tem 34
-- milhoes delas.
WITH chave(fato, dimensao, valor) AS (
    SELECT DISTINCT 'fato_tarifa', 'dim_calendario', mes::VARCHAR FROM fato_tarifa
    UNION ALL SELECT DISTINCT 'fato_tarifa', 'dim_grupo', grupo FROM fato_tarifa
    UNION ALL SELECT DISTINCT 'fato_tarifa', 'dim_mercado', mercado FROM fato_tarifa
    UNION ALL SELECT DISTINCT 'fato_voo', 'dim_calendario', mes::VARCHAR FROM fato_voo
    UNION ALL SELECT DISTINCT 'fato_voo', 'dim_grupo', grupo FROM fato_voo
    UNION ALL SELECT DISTINCT 'fato_voo', 'dim_mercado', mercado FROM fato_voo
    UNION ALL SELECT DISTINCT 'fato_voo', 'dim_empresa', empresa FROM fato_voo
    UNION ALL SELECT DISTINCT 'fato_voo', 'dim_aeroporto', origem FROM fato_voo
    UNION ALL SELECT DISTINCT 'fato_voo', 'dim_aeroporto', destino FROM fato_voo
    UNION ALL SELECT DISTINCT 'fato_oferta', 'dim_calendario', mes::VARCHAR FROM fato_oferta
    UNION ALL SELECT DISTINCT 'fato_oferta', 'dim_grupo', grupo FROM fato_oferta
    UNION ALL SELECT DISTINCT 'fato_oferta', 'dim_mercado', mercado FROM fato_oferta
),
dimensao(dimensao, valor) AS (
    SELECT 'dim_calendario', mes::VARCHAR FROM dim_calendario
    UNION ALL SELECT 'dim_grupo', grupo FROM dim_grupo
    UNION ALL SELECT 'dim_mercado', mercado FROM dim_mercado
    UNION ALL SELECT 'dim_empresa', empresa FROM dim_empresa
    UNION ALL SELECT 'dim_aeroporto', icao FROM dim_aeroporto
)
SELECT DISTINCT c.fato, c.dimensao, coalesce(c.valor, 'nulo') AS chave_orfa
FROM chave AS c
WHERE NOT EXISTS (
    SELECT 1 FROM dimensao AS d WHERE d.dimensao = c.dimensao AND d.valor = c.valor
)
ORDER BY ALL;
