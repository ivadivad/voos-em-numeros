-- Calendario mensal: um registro por mes, do primeiro ao ultimo mes que
-- aparece nas tres bases, sem buraco. Os fatos sao mensais (o mes da venda
-- nas tarifas, o do voo na base estatistica, o do arquivo no VRA), e o
-- calendario e a dimensao que os tres compartilham.
--
-- Sem buraco mesmo onde uma base falta: fev e mar/2020 nao tem voo do VRA
-- (ver 11_stg_voos.sql), mas tem tarifa e base estatistica, e o painel
-- precisa mostrar o buraco, nao pular o mes.
--
-- Vai pra dados/marts/dim_calendario.parquet, que o painel le em vez de
-- recriar o calendario no Power Query.
CREATE OR REPLACE TABLE dim_calendario AS
WITH limites AS (
    -- no VRA, o mes e o do arquivo, como no mart de validacao
    SELECT
        least(t.primeiro, e.primeiro, v.primeiro) AS primeiro,
        greatest(t.ultimo, e.ultimo, v.ultimo) AS ultimo
    FROM (SELECT min(mes) AS primeiro, max(mes) AS ultimo FROM stg_tarifas) AS t,
         (SELECT min(mes) AS primeiro, max(mes) AS ultimo FROM stg_estatisticas) AS e,
         (SELECT strptime(left(min(arquivo), 6), '%Y%m')::DATE AS primeiro,
                 strptime(left(max(arquivo), 6), '%Y%m')::DATE AS ultimo FROM stg_voos) AS v
),
meses AS (
    SELECT unnest(generate_series(primeiro, ultimo, INTERVAL 1 MONTH))::DATE AS mes
    FROM limites
),
nomes(numero, nome) AS (
    VALUES (1, 'janeiro'), (2, 'fevereiro'), (3, 'março'), (4, 'abril'), (5, 'maio'), (6, 'junho'),
           (7, 'julho'), (8, 'agosto'), (9, 'setembro'), (10, 'outubro'), (11, 'novembro'), (12, 'dezembro')
)
SELECT
    m.mes,  -- o dia 1 do mes: a chave que os fatos usam
    year(m.mes) AS ano,
    quarter(m.mes) AS trimestre,
    month(m.mes) AS numero_mes,
    n.nome AS nome_mes,
    left(n.nome, 3) AS mes_abreviado,
    left(n.nome, 3) || '/' || year(m.mes) AS rotulo  -- ago/2026, como o projeto escreve
FROM meses AS m
JOIN nomes AS n ON n.numero = month(m.mes);

COPY (SELECT * FROM dim_calendario ORDER BY mes)
TO 'dados/marts/dim_calendario.parquet' (FORMAT parquet);
