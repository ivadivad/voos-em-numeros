-- Base estatistica padronizada: uma linha por empresa, mes, par de
-- aerodromos e grupo de voo, no mercado domestico, de jan/2019 em diante.
--
-- Os passageiros vem da etapa combinada; assentos, decolagens, distancia,
-- ASK e RPK, da basica (ver DICIONARIO.md). Por isso ha linha com
-- passageiro e sem assento (par de embarque e desembarque sem perna direta)
-- e o contrario: ali o nulo quer dizer "nao se aplica", e quem separa isso
-- de valor que nao converteu e o teste.
--
-- So natureza DOMESTICA, o escopo do projeto. As internacionais ficam de
-- fora aqui, junto com as 7 linhas de 2019 sem aeroporto de origem, todas
-- de empresa estrangeira. O grupo de voo (REGULAR, NAO REGULAR,
-- IMPRODUTIVO) fica como coluna: qual entra em cada conta e decisao das
-- etapas seguintes.
CREATE OR REPLACE TABLE stg_estatisticas AS
SELECT
    TRY_CAST(ano || '-' || lpad(mes, 2, '0') || '-01' AS DATE) AS mes,
    upper(trim(empresa)) AS empresa,
    trim(empresa_nome) AS empresa_nome,
    upper(trim(origem)) AS origem,
    upper(trim(destino)) AS destino,
    grupo_de_voo,
    TRY_CAST(passageiros_pagos AS BIGINT) AS passageiros_pagos,
    TRY_CAST(passageiros_gratis AS BIGINT) AS passageiros_gratis,
    TRY_CAST(assentos AS BIGINT) AS assentos,
    TRY_CAST(decolagens AS BIGINT) AS decolagens,
    TRY_CAST(distancia_voada_km AS BIGINT) AS distancia_voada_km,  -- soma de todas as decolagens
    TRY_CAST(ask AS BIGINT) AS ask,
    TRY_CAST(rpk AS BIGINT) AS rpk
FROM bruto_estatisticas
WHERE natureza = 'DOMÉSTICA'
  AND TRY_CAST(ano AS INTEGER) >= 2019;
