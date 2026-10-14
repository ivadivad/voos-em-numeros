-- A flag de cancelado compara o texto exato 'CANCELADO'. Uma situacao nova
-- (ou a mesma escrita de outro jeito) faria voo cancelado contar como nao
-- cancelado, sem erro nenhum.
SELECT situacao, count(*) AS voos
FROM stg_voos
WHERE situacao NOT IN ('REALIZADO', 'CANCELADO', 'NÃO INFORMADO')
GROUP BY situacao;
