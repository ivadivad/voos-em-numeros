-- Horario que existia no bruto (nao era o texto "null") e nao virou
-- timestamp. Confere todas as linhas do VRA, nao so as domesticas, menos as
-- corrompidas de fev e mar/2020, que a staging descarta.
SELECT arquivo, empresa, voo, partida_prevista, partida_real, chegada_prevista, chegada_real
FROM bruto_vra
WHERE NOT list_contains([partida_prevista, partida_real, chegada_prevista, chegada_real, situacao],
                        'Microsoft.SqlServer.Dts.Pipeline.BlobColumn')
  AND (   (partida_prevista <> 'null' AND horario(partida_prevista) IS NULL)
       OR (partida_real <> 'null' AND horario(partida_real) IS NULL)
       OR (chegada_prevista <> 'null' AND horario(chegada_prevista) IS NULL)
       OR (chegada_real <> 'null' AND horario(chegada_real) IS NULL));
