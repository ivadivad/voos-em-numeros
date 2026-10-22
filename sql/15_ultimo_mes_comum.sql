-- O modelo termina no ultimo mes que as tres bases mensais tem. A ANAC
-- publica cada uma num dia diferente: as tarifas de 15 a 28 dias depois do
-- fim do mes, a base estatistica perto do dia 14, o VRA perto do dia 28
-- (ver README, "Notas sobre as fontes"). Numa coleta feita no meio do mes,
-- uma base chega um mes na frente das outras, e esse mes entraria nos
-- marts pela metade: com tarifa e sem voo, por exemplo, e com a janela dos
-- 12 meses mais recentes andando so de um lado.
--
-- O mes a mais sai da staging aqui, antes das dimensoes e dos fatos, e
-- volta sozinho na construcao seguinte, quando as outras bases chegarem
-- nele: os brutos continuam no disco, e a dados/cobertura.csv registra o
-- que ja saiu. Os testes do bruto (formato, conversao) continuam olhando
-- todos os arquivos, o mes a mais inclusive.
--
-- A tabela guarda o ultimo mes de cada base antes do corte, pra quem
-- construir ver o que ficou de fora; o teste bases_terminam_no_mesmo_mes
-- confere que o calendario, os fatos e os marts terminam no mes comum.
CREATE OR REPLACE TABLE ultimo_mes_comum AS
WITH ultimos AS (
    SELECT
        (SELECT max(mes) FROM stg_tarifas) AS tarifas,
        (SELECT max(mes) FROM stg_estatisticas) AS estatisticas,
        -- no VRA, o mes e o do arquivo, como no fato e no calendario
        (SELECT strptime(left(max(arquivo), 6), '%Y%m')::DATE FROM stg_voos) AS voos
)
SELECT least(tarifas, estatisticas, voos) AS mes, tarifas, estatisticas, voos
FROM ultimos;

DELETE FROM stg_tarifas
WHERE mes > (SELECT mes FROM ultimo_mes_comum);

DELETE FROM stg_estatisticas
WHERE mes > (SELECT mes FROM ultimo_mes_comum);

DELETE FROM stg_voos
WHERE strptime(left(arquivo, 6), '%Y%m')::DATE > (SELECT mes FROM ultimo_mes_comum);
