-- O grupos.csv e feito a mao, e erro de digitacao nele nao quebra a
-- construcao: muda o grupo em silencio. Confere que toda linha tem fonte (um
-- ou mais enderecos), que o desde preenchido vira data, que a mesma empresa
-- nao tem dois periodos com o mesmo inicio, que cada empresa e cada grupo
-- tem um nome so, e as ligacoes que a etapa 5 pesquisou: a Azul Conecta na
-- Azul, depois da compra da TwoFlex, e a MAP na VoePass.
WITH esperado(empresa, mes, grupo) AS (
    VALUES ('ACN', DATE '2019-01-01', 'TWOFLEX'), ('ACN', DATE '2020-06-01', 'AZUL'),
           ('ACN', DATE '2026-08-01', 'AZUL'), ('OWT', DATE '2021-11-01', 'AZUL'),
           ('PAM', DATE '2019-08-01', 'MAP'), ('PAM', DATE '2024-01-01', 'VOEPASS'),
           ('PTB', DATE '2024-01-01', 'VOEPASS'), ('TAM', DATE '2026-08-01', 'LATAM'),
           ('LTG', DATE '2026-08-01', 'LATAM')
)
SELECT 'sem fonte' AS problema, empresa, desde AS detalhe
FROM ref_grupos
WHERE NOT coalesce(regexp_full_match(fonte, 'https?://\S+( https?://\S+)*'), false)
UNION ALL
SELECT 'desde que nao vira data', empresa, desde
FROM ref_grupos
WHERE desde IS NOT NULL AND TRY_CAST(desde || '-01' AS DATE) IS NULL
UNION ALL
SELECT 'dois periodos com o mesmo inicio', empresa, any_value(desde)
FROM ref_grupos
GROUP BY empresa, desde
HAVING count(*) > 1
UNION ALL
SELECT 'mais de um nome pra empresa', empresa, string_agg(DISTINCT nome_empresa, ' | ')
FROM ref_grupos
GROUP BY empresa
HAVING count(DISTINCT nome_empresa) > 1
UNION ALL
SELECT 'mais de um nome pro grupo', grupo, string_agg(DISTINCT nome_grupo, ' | ')
FROM ref_grupos
GROUP BY grupo
HAVING count(DISTINCT nome_grupo) > 1
UNION ALL
SELECT 'grupo diferente do pesquisado', e.empresa, e.mes || ': ' || e.grupo || ' esperado, ' || coalesce(g.grupo, 'nenhum')
FROM esperado AS e
LEFT JOIN empresa_grupo AS g ON g.empresa = e.empresa AND no_periodo(e.mes, g.desde, g.ate)
WHERE g.grupo IS DISTINCT FROM e.grupo;
