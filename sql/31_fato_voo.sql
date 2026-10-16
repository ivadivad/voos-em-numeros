-- Fato dos voos: um registro por voo do VRA (a etapa, uma decolagem e o
-- pouso seguinte), com os horarios, a situacao e o atraso na chegada da
-- stg_voos, que ja resolveu as copias e os registros que se contradizem
-- (11_stg_voos.sql). Ganha as chaves das dimensoes: o mes, a empresa que
-- operou, o grupo dela naquele mes, o mercado e os dois aeroportos.
--
-- O mes e o do arquivo, que e como a ANAC agrupa os voos (a partida
-- prevista, ou a real nas etapas nao planejadas) e como o mart de
-- validacao contou. Nao e o mes da venda das tarifas: tarifa e voo do
-- mesmo mes nao sao as mesmas viagens.
--
-- Fica de fora o voo entre dois aeroportos da mesma cidade, que nao forma
-- mercado: na coleta de 13/10/2026, 823 voos, 706 deles entre os
-- aeroportos de Sao Paulo e 27 que voltaram pro aeroporto de onde sairam.
-- O teste de fechamento conta quanto saiu.
--
-- Grupo ou aeroporto que faltar na dimensao nao derruba a linha: ela fica
-- com a chave nula, e o teste de integridade referencial aponta.
CREATE OR REPLACE TABLE fato_voo AS
WITH voo AS (
    SELECT strptime(left(arquivo, 6), '%Y%m')::DATE AS mes, *
    FROM stg_voos
)
SELECT
    v.mes,
    v.empresa,
    g.grupo,
    chave_mercado(o.cidade, d.cidade) AS mercado,
    v.origem,
    v.destino,
    v.voo,
    v.partida_prevista,
    v.partida_real,
    v.chegada_prevista,
    v.chegada_real,
    v.situacao,
    v.cancelado,
    v.atraso_chegada_min
FROM voo AS v
LEFT JOIN empresa_grupo AS g ON g.empresa = v.empresa AND no_periodo(v.mes, g.desde, g.ate)
LEFT JOIN dim_aeroporto AS o ON o.icao = v.origem
LEFT JOIN dim_aeroporto AS d ON d.icao = v.destino
WHERE NOT coalesce(o.cidade = d.cidade, false);
