-- Toda empresa das tres bases tem exatamente um grupo em cada mes em que
-- aparece. A lista sai das staging, nao de memoria: empresa nova numa coleta
-- aparece aqui sem grupo. Zero grupos faria as linhas dela sumirem dos fatos;
-- dois, periodos sobrepostos no grupos.csv, as contariam duas vezes.
WITH nas_bases AS (
    SELECT DISTINCT empresa, mes FROM stg_tarifas
    UNION
    SELECT DISTINCT empresa, mes FROM stg_estatisticas
    UNION
    SELECT DISTINCT empresa, strptime(left(arquivo, 6), '%Y%m')::DATE FROM stg_voos
)
SELECT b.empresa, min(b.mes) AS primeiro_mes, max(b.mes) AS ultimo_mes, count(*) AS meses, grupos
FROM (
    SELECT b.empresa, b.mes, count(g.grupo) AS grupos
    FROM nas_bases AS b
    LEFT JOIN empresa_grupo AS g ON g.empresa = b.empresa AND no_periodo(b.mes, g.desde, g.ate)
    GROUP BY b.empresa, b.mes
) AS b
WHERE grupos <> 1
GROUP BY b.empresa, grupos;
