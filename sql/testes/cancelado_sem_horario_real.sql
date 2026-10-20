-- Voo que nao foi realizado (cancelado ou com situacao NAO INFORMADO) nao
-- tem horario real nem atraso; voo realizado tem os dois horarios reais.
-- Um cancelado com chegada real entraria no atraso e no cancelamento ao
-- mesmo tempo; um realizado sem chegada real sumiria do atraso sem aviso.
-- Na coleta de 13/10/2026, 122.722 cancelados e 1.158 nao informados na
-- staging, nenhum com horario real.
SELECT situacao AS problema, empresa, voo, partida_prevista, partida_real, chegada_real, atraso_chegada_min
FROM stg_voos
WHERE (situacao <> 'REALIZADO'
       AND (partida_real IS NOT NULL OR chegada_real IS NOT NULL OR atraso_chegada_min IS NOT NULL))
   OR (situacao = 'REALIZADO' AND (partida_real IS NULL OR chegada_real IS NULL));
