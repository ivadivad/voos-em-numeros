-- O atraso na chegada e a diferenca entre a chegada real e a prevista, em
-- minutos, voo a voo: recalculado aqui pela subtracao dos dois horarios,
-- e nao pelo epoch de cada um, como na staging. Meio minuto de folga pro
-- arredondamento: na coleta de 13/10/2026, 3.819 voos tem o horario
-- previsto fora do minuto cheio, e a staging arredonda (-187,95 vira -188).
-- Sao 11 de 27/04/2019 com 57 segundos (PAM e OWT) e 3.808 com um decimo de
-- segundo (07:45:00.1), de nov/2024 em diante, em sete empresas.
--
-- Confere tambem as duas fronteiras da decisao 4 da staging: atraso so ate
-- dois dias, e nenhum atraso perdido abaixo disso. Na coleta de 13/10/2026,
-- 8 voos passam de dois dias e ficam sem atraso.
WITH voo AS (
    SELECT empresa, voo, chegada_prevista, chegada_real, atraso_chegada_min,
           epoch(chegada_real - chegada_prevista) / 60 AS minutos
    FROM stg_voos
)
SELECT 'atraso diferente da diferenca dos horarios' AS problema, empresa, voo, chegada_prevista,
       atraso_chegada_min, minutos
FROM voo
WHERE atraso_chegada_min IS NOT NULL AND abs(atraso_chegada_min - minutos) > 0.5
UNION ALL
SELECT 'atraso de mais de dois dias', empresa, voo, chegada_prevista, atraso_chegada_min, minutos
FROM voo
WHERE atraso_chegada_min IS NOT NULL AND abs(minutos) > 2 * 24 * 60
UNION ALL
SELECT 'atraso perdido: os dois horarios, ate dois dias', empresa, voo, chegada_prevista, atraso_chegada_min, minutos
FROM voo
WHERE atraso_chegada_min IS NULL AND abs(minutos) <= 2 * 24 * 60;
