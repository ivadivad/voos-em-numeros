-- A staging dos voos descarta as linhas corrompidas pelo conteudo (o texto
-- 'Microsoft.SqlServer.Dts.Pipeline.BlobColumn' no lugar dos horarios), nao
-- pelo mes. Na coleta de 13/10/2026 sao todas as linhas de fev e mar/2020.
-- Se o defeito aparecer em outro arquivo, um mes inteiro sumiria da staging
-- sem aviso: o teste devolve o arquivo.
SELECT arquivo, count(*) AS linhas_corrompidas
FROM bruto_vra
WHERE list_contains([partida_prevista, partida_real, chegada_prevista, chegada_real, situacao],
                    'Microsoft.SqlServer.Dts.Pipeline.BlobColumn')
  AND arquivo NOT IN ('202002.csv', '202003.csv')
GROUP BY arquivo;
