-- O mart da fusao tem um registro por janela e mercado, e os passageiros de
-- cada janela sao exatamente os passageiros regulares do fato_oferta nos 12
-- meses dela. E a janela tem 12 meses: a de 2024 e os 12 mais recentes.
WITH janela AS (
    SELECT DISTINCT janela, inicio, fim FROM mart_fusao
),
fato AS (
    SELECT j.janela, sum(o.passageiros_pagos) AS passageiros
    FROM fato_oferta AS o
    JOIN janela AS j ON o.mes BETWEEN j.inicio AND j.fim
    WHERE o.grupo_de_voo = 'REGULAR'
    GROUP BY j.janela
),
mart AS (
    SELECT janela, sum(passageiros) AS passageiros FROM mart_fusao GROUP BY janela
)
SELECT 'registro repetido ou chave nula' AS problema, janela, mercado AS detalhe
FROM mart_fusao
GROUP BY janela, mercado
HAVING count(*) > 1 OR janela IS NULL OR mercado IS NULL
UNION ALL
SELECT 'janela sem 12 meses', janela, inicio || ' a ' || fim
FROM janela
WHERE date_diff('month', inicio, fim) <> 11
UNION ALL
SELECT 'janela que nao e a declarada', janela, NULL
FROM janela
WHERE janela NOT IN ('2024', '12 meses mais recentes')
   OR (janela = '2024' AND (inicio, fim) <> (DATE '2024-01-01', DATE '2024-12-01'))
   OR (janela = '12 meses mais recentes' AND fim <> (SELECT max(mes) FROM fato_oferta))
UNION ALL
SELECT 'passageiros diferentes do fato', janela, f.passageiros || ' no fato, ' || m.passageiros || ' no mart'
FROM fato AS f
FULL JOIN mart AS m USING (janela)
WHERE f.passageiros IS DISTINCT FROM m.passageiros;
