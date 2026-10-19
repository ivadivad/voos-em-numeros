-- A leitura do guia do CADE (macro leitura_cade, 60_mart_fusao.sql) nos
-- casos de fronteira do texto da secao 2.4.2: HHI de 1.500 e 2.500, e
-- variacao de 100 e 200. "Abaixo de 1.500" nao inclui o 1.500; "entre
-- 1.500 e 2.500" inclui os dois; "acima de 2.500" nao inclui o 2.500;
-- "inferiores a 100" nao inclui o 100; "entre 100 e 200" inclui os dois.
-- E o mart usa a mesma macro em todo registro. Devolve o caso que deu
-- outra leitura.
WITH caso(hhi_depois, delta, esperado) AS (
    VALUES (1000.0, 99.9, 'variação pequena'),
           (9000.0, 99.9, 'variação pequena'),
           (1499.9, 150.0, 'mercado não concentrado'),
           (1500.0, 150.0, 'potencial preocupação'),
           (2500.0, 150.0, 'potencial preocupação'),
           (2500.0, 250.0, 'potencial preocupação'),
           (2000.0, 100.0, 'sem leitura no guia'),
           (2000.0, 100.1, 'potencial preocupação'),
           (2500.1, 100.0, 'potencial preocupação'),
           (2500.1, 200.0, 'potencial preocupação'),
           (2500.1, 200.1, 'presunção de poder de mercado'),
           (10000.0, 5000.0, 'presunção de poder de mercado')
)
SELECT 'caso de fronteira' AS problema, hhi_depois || ' / ' || delta AS caso, esperado,
       leitura_cade(hhi_depois, delta) AS obtido
FROM caso
WHERE leitura_cade(hhi_depois, delta) IS DISTINCT FROM esperado
UNION ALL
SELECT 'mart com leitura diferente da macro', janela || ' ' || mercado, leitura_cade(hhi_depois, delta_hhi), leitura
FROM mart_fusao
WHERE leitura IS DISTINCT FROM leitura_cade(hhi_depois, delta_hhi);
