-- O mes de cada linha tem que ser o do nome do arquivo. No MED, a consulta
-- de um mes trazia os meses seguintes; aqui, linha de outro mes num arquivo
-- seria contada no mes errado, ou duas vezes.
SELECT arquivo, mes, count(*) AS linhas
FROM stg_tarifas
WHERE strftime(mes, '%Y%m') || '.csv' <> arquivo
GROUP BY ALL;
