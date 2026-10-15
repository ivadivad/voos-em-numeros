-- O grao do mart de validacao: um registro por mes e empresa.
SELECT mes, empresa, count(*) AS linhas
FROM mart_validacao
GROUP BY mes, empresa
HAVING count(*) > 1 OR mes IS NULL OR empresa IS NULL;
