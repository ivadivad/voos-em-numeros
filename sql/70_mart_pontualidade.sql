-- Marts de pontualidade: os voos previstos do VRA, com os realizados, os
-- cancelados e os atrasados na chegada, em dois recortes, pra nenhum
-- arquivo ficar grande. Vao pra dados/marts/pontualidade_rota.parquet e
-- dados/marts/pontualidade_horario.parquet, que o notebook 05 le pela URL
-- bruta do GitHub.
--
-- Cinco decisoes:
--
-- 1. So os voos previstos, os que tem partida prevista. As etapas nao
--    planejadas (13.749 voos na coleta de 13/10/2026, todos realizados) nao
--    tem horario previsto, e sem ele nao ha atraso nem hora no mapa de
--    calor. O teste de fechamento conta quantos ficam de fora.
--
-- 2. O primeiro recorte e por rota: grupo, mes, aeroporto de origem e de
--    destino, com o mercado. O plano previa grupo, aeroporto e mes; a rota
--    contem esse recorte, cabe em menos de 1 MB (98.670 registros) e serve
--    ao aeroporto de partida, ao de chegada e ao mercado, que a comparacao
--    com a tarifa por km precisa. O segundo e por grupo, mes, dia da semana
--    e hora da partida prevista, no horario de Brasilia, que e o do VRA (ver
--    DICIONARIO.md). Dia da semana de 1 (segunda) a 7 (domingo), o padrao
--    ISO.
--
-- 3. A situacao NAO INFORMADO (1.158 voos, de ago/2020 a out/2023) fica
--    numa coluna propria: pela decisao do Davi (19/10/2026), fica fora da
--    conta principal e entra como sensibilidade. Previstos sao os
--    realizados, os cancelados e os nao informados.
--
-- 4. O atraso e na chegada, acima de 15, 30 e 60 minutos, e se conta sobre
--    os voos com atraso medido: os realizados menos os 8 com data trocada,
--    que a staging deixa sem atraso (11_stg_voos.sql). Cada corte contem o
--    seguinte.
--
-- 5. Duas colunas pras pontas, que os dados nao separam de mudanca de
--    horario ou de dia (ver DICIONARIO.md): os que chegaram 2 h ou mais
--    antes do previsto (1.817), que pelo corte contam como no horario, e os
--    que chegaram 23 h ou mais depois (263), que contam como atrasados. Com
--    elas, o notebook confere se tira-los muda a ordem dos grupos.
--
-- So contagens, nenhuma media: o percentual sai da razao entre as somas, e
-- assim continua certo em qualquer recorte.
CREATE OR REPLACE VIEW voo_previsto AS
SELECT
    mes,
    grupo,
    mercado,
    origem,
    destino,
    isodow(partida_prevista) AS dia_semana,
    hour(partida_prevista) AS hora,
    situacao = 'REALIZADO' AS realizado,
    cancelado,
    situacao = 'NÃO INFORMADO' AS nao_informado,
    atraso_chegada_min AS atraso
FROM fato_voo
WHERE partida_prevista IS NOT NULL;

CREATE OR REPLACE TABLE mart_pontualidade_rota AS
SELECT
    mes, grupo, mercado, origem, destino,
    count(*) AS voos_previstos,
    count(*) FILTER (WHERE realizado) AS voos_realizados,
    count(*) FILTER (WHERE cancelado) AS voos_cancelados,
    count(*) FILTER (WHERE nao_informado) AS voos_nao_informados,
    count(atraso) AS voos_medidos,
    count(*) FILTER (WHERE atraso > 15) AS voos_atraso_15,
    count(*) FILTER (WHERE atraso > 30) AS voos_atraso_30,
    count(*) FILTER (WHERE atraso > 60) AS voos_atraso_60,
    count(*) FILTER (WHERE atraso <= -120) AS voos_adiantados_2h,
    count(*) FILTER (WHERE atraso >= 23 * 60) AS voos_atraso_23h
FROM voo_previsto
GROUP BY mes, grupo, mercado, origem, destino;

CREATE OR REPLACE TABLE mart_pontualidade_horario AS
SELECT
    mes, grupo, dia_semana, hora,
    count(*) AS voos_previstos,
    count(*) FILTER (WHERE realizado) AS voos_realizados,
    count(*) FILTER (WHERE cancelado) AS voos_cancelados,
    count(*) FILTER (WHERE nao_informado) AS voos_nao_informados,
    count(atraso) AS voos_medidos,
    count(*) FILTER (WHERE atraso > 15) AS voos_atraso_15,
    count(*) FILTER (WHERE atraso > 30) AS voos_atraso_30,
    count(*) FILTER (WHERE atraso > 60) AS voos_atraso_60,
    count(*) FILTER (WHERE atraso <= -120) AS voos_adiantados_2h,
    count(*) FILTER (WHERE atraso >= 23 * 60) AS voos_atraso_23h
FROM voo_previsto
GROUP BY mes, grupo, dia_semana, hora;

COPY (SELECT * FROM mart_pontualidade_rota ORDER BY mes, grupo, origem, destino)
TO 'dados/marts/pontualidade_rota.parquet' (FORMAT parquet);

COPY (SELECT * FROM mart_pontualidade_horario ORDER BY mes, grupo, dia_semana, hora)
TO 'dados/marts/pontualidade_horario.parquet' (FORMAT parquet);
