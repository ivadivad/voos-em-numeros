-- O grao do fato das tarifas: um registro por grupo, mercado, mes e valor
-- de tarifa, com assentos. Repeticao aqui contaria assentos duas vezes em
-- qualquer recorte; assentos zerados ou negativos seriam linha que nao
-- devia existir.
SELECT mes, grupo, mercado, tarifa, count(*) AS linhas, min(assentos) AS menor
FROM fato_tarifa
GROUP BY mes, grupo, mercado, tarifa
HAVING count(*) > 1 OR min(assentos) <= 0;
