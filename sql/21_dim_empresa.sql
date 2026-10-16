-- Empresas e grupos economicos, a partir de dados/referencia/grupos.csv,
-- feito a mao: uma linha por empresa e periodo, com a fonte de cada ligacao.
--
-- O HHI mede concentracao entre donos, nao entre marcas: subsidiaria que
-- contasse como concorrente da controladora faria o mercado parecer mais
-- disputado do que e. As 24 empresas das tres bases (11 nas tarifas, 22 na
-- base estatistica, 19 no VRA) formam 21 grupos. Quatro decisoes:
--
-- 1. O grupo muda no tempo, e o mes em que o controle muda fica com o dono
--    anterior: o grupo novo vale a partir do primeiro mes inteiro.
--    - A TwoFlex e da Azul a partir de jun/2020: a Azul anunciou a conclusao
--      da compra em 14/05/2020.
--    - A MAP e da VoePass (a Passaredo) a partir de set/2019: a compra de
--      100% do controle foi anunciada em 21/08/2019. A venda da MAP pra GOL,
--      anunciada em jun/2021 e aprovada pelo CADE, nao foi concluida: em
--      26/04/2023 o Valor noticiou que a "compra de MAP nao devera ocorrer"
--      e que Passaredo e MAP "sao da Voepass".
--    Antes da compra, as duas formam grupo proprio. Pesa pouco: na coleta
--    de 13/10/2026, 118.942 passageiros pagos, 93.678 assentos vendidos e
--    11.723 voos ficam fora da Azul e da VoePass por isso.
--
-- 2. Dois codigos, uma empresa: a TwoFlex e OWT nas tarifas e no VRA, e ACN
--    na base estatistica, que a chama "AZUL CONECTA LTDA. (EX TWO TAXI
--    AEREO LTDA)" desde jan/2019. No VRA, os mesmos numeros de voo passam
--    de OWT pra ACN ao longo de 2021. Os dois codigos ficam, cada um com os
--    mesmos periodos.
--
-- 3. Carga e estrangeira tambem tem grupo: a ABSA (LTG, a LATAM Cargo) e a
--    LATAM Argentina (DSM, com um voo so, de Viracopos a Guarulhos) entram
--    na LATAM. Nao mudam nenhuma conta por passageiro, mas toda empresa das
--    bases precisa de grupo, ou o voo dela sumiria do fato.
--
-- 4. Empresa sem ligacao societaria conhecida com outra das bases forma
--    grupo proprio, e a fonte dela e a base estatistica da ANAC, que a
--    identifica. So as ligacoes tem fonte de fora.
CREATE OR REPLACE VIEW ref_grupos AS
SELECT *
FROM read_csv('dados/referencia/grupos.csv', header = true, all_varchar = true);

-- verdadeiro quando o mes cai no periodo [desde, ate); nulo nas pontas quer
-- dizer sem limite
CREATE OR REPLACE MACRO no_periodo(mes, desde, ate) AS
    (desde IS NULL OR mes >= desde) AND (ate IS NULL OR mes < ate);

-- a historia: cada periodo vai do proprio desde ate o desde seguinte da
-- mesma empresa. Os fatos acham o grupo de cada linha pelo mes
CREATE OR REPLACE TABLE empresa_grupo AS
SELECT
    empresa,
    grupo,
    TRY_CAST(desde || '-01' AS DATE) AS desde,
    lead(TRY_CAST(desde || '-01' AS DATE)) OVER (PARTITION BY empresa ORDER BY desde NULLS FIRST) AS ate,
    fonte
FROM ref_grupos;

CREATE OR REPLACE TABLE dim_grupo AS
SELECT grupo, min(nome_grupo) AS nome_grupo
FROM ref_grupos
GROUP BY grupo;

-- o nome curto vem do grupos.csv; o da ANAC, da base estatistica, onde a
-- empresa aparece (OWT e DSM nao aparecem)
CREATE OR REPLACE TABLE dim_empresa AS
SELECT
    r.empresa,
    min(r.nome_empresa) AS nome_empresa,
    min(e.empresa_nome) AS nome_anac
FROM ref_grupos AS r
LEFT JOIN (SELECT DISTINCT empresa, empresa_nome FROM stg_estatisticas) AS e USING (empresa)
GROUP BY r.empresa;

COPY (SELECT * FROM dim_grupo ORDER BY grupo)
TO 'dados/marts/dim_grupo.parquet' (FORMAT parquet);

COPY (SELECT * FROM dim_empresa ORDER BY empresa)
TO 'dados/marts/dim_empresa.parquet' (FORMAT parquet);
