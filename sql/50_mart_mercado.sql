-- Mart de mercado por mes: um registro por mercado, mes e grupo, com os
-- passageiros e a participacao de cada grupo e as somas da tarifa. E a base
-- da comparacao entre concorrencia e preco (notebook 02) e da concentracao
-- dos mercados nas etapas seguintes. Vai pra dados/marts/mercado_mes.parquet,
-- que o notebook le pela URL bruta do GitHub.
--
-- Cinco decisoes, as tres primeiras do Davi (17/10/2026):
--
-- 1. A participacao de cada grupo e pelos passageiros pagos de voo regular
--    (fato_oferta), e nao pelos assentos vendidos das tarifas, que deixam de
--    fora programas de milhagem e descontos restritos a grupos (ver
--    DICIONARIO.md). O fretamento (NAO REGULAR, 2,8% dos
--    passageiros) fica numa coluna a parte, fora da participacao, pra
--    servir de sensibilidade.
--
-- 2. So entram os mercado-meses com passageiro de voo regular direto, os
--    unicos em que a participacao existe: na coleta de 13/10/2026, 30.886
--    dos 285.781 mercado-meses com tarifa. Os outros sao mercados so de
--    conexao (o passageiro troca de voo no caminho), com 41.011.634
--    assentos vendidos, 18,16% do total, e 9,9% do fretamento. Ficam de
--    fora, e o teste de fechamento conta.
--
-- 3. Tarifa e passageiro nao sao as mesmas viagens: a tarifa e do grupo que
--    vendeu, no mes da venda; o passageiro, do grupo que operou, no mes do
--    voo (ver DICIONARIO.md). O registro junta os dois no mesmo mercado e
--    mes como retrato da estrutura do mercado, que muda devagar, e nao como
--    o preco pago por aqueles passageiros.
--
-- 4. Da tarifa, so somas: assentos vendidos, receita (tarifa vezes
--    assentos) e assentos-km. A tarifa media e a tarifa por km saem da razao
--    entre as somas, como na etapa 4, e assim continuam certas em qualquer
--    recorte. A participacao e uma medida do mercado no mes e nao se soma
--    entre registros.
--
-- 5. Assentos-km sao os assentos vendidos vezes a distancia do mercado
--    (23_dim_mercado.sql). Mercado sem distancia fica com assentos-km nulo,
--    nao zero, pra sair da tarifa por km sem puxa-la pra cima: no escopo,
--    sao 3 mercado-meses, com 580 assentos vendidos.
--
-- A concentracao do mercado no mes vem repetida em cada registro dele: o
-- numero de concorrentes e o HHI. Como a participacao, sao medidas do
-- mercado no mes, e nao se somam entre registros.

-- Concorrente e o grupo com pelo menos 5% dos passageiros regulares do
-- mercado no mes: um grupo com dois voos no ano nao disputa o mercado.
-- Decisao do Davi (17/10/2026), com 10% como sensibilidade no notebook 02.
-- O limite mora so aqui; o mart e o teste usam esta macro.
CREATE OR REPLACE MACRO limite_concorrente() AS 0.05;

CREATE OR REPLACE TABLE mart_mercado_mes AS
WITH oferta AS (
    SELECT
        mes, mercado, grupo,
        sum(passageiros_pagos) FILTER (WHERE grupo_de_voo = 'REGULAR') AS passageiros_pagos,
        sum(passageiros_pagos) FILTER (WHERE grupo_de_voo = 'NÃO REGULAR') AS passageiros_nao_regular
    FROM fato_oferta
    GROUP BY mes, mercado, grupo
),
tarifa AS (
    SELECT mes, mercado, grupo, sum(assentos) AS assentos_vendidos, sum(tarifa * assentos) AS receita
    FROM fato_tarifa
    GROUP BY mes, mercado, grupo
),
com_voo_regular AS (
    SELECT mes, mercado
    FROM oferta
    GROUP BY mes, mercado
    HAVING sum(passageiros_pagos) > 0
),
linha AS (
    SELECT
        mes, mercado, grupo,
        coalesce(o.passageiros_pagos, 0) AS passageiros_pagos,
        coalesce(o.passageiros_nao_regular, 0) AS passageiros_nao_regular,
        coalesce(t.assentos_vendidos, 0) AS assentos_vendidos,
        coalesce(t.receita, 0) AS receita
    FROM oferta AS o
    FULL JOIN tarifa AS t USING (mes, mercado, grupo)
    JOIN com_voo_regular USING (mes, mercado)
    -- grupo so com voo improdutivo no mercado nao tem passageiro nem tarifa
    WHERE coalesce(o.passageiros_pagos, 0) > 0 OR coalesce(o.passageiros_nao_regular, 0) > 0
       OR coalesce(t.assentos_vendidos, 0) > 0
),
participacao AS (
    -- divisao de somas inteiras: o resultado nao depende da ordem
    SELECT *, passageiros_pagos / sum(passageiros_pagos) OVER (PARTITION BY mes, mercado) AS participacao
    FROM linha
)
SELECT
    p.mes,
    p.mercado,
    p.grupo,
    p.passageiros_pagos::BIGINT AS passageiros_pagos,
    p.passageiros_nao_regular::BIGINT AS passageiros_nao_regular,
    p.participacao,
    count(*) FILTER (WHERE p.participacao >= limite_concorrente()) OVER mercado_no_mes AS concorrentes,
    -- HHI: 10.000 vezes a soma dos quadrados das participacoes, de 10.000/n
    -- (n grupos iguais) a 10.000 (um grupo so). Sai das somas inteiras dos
    -- passageiros, numa divisao so, e nao da soma dos quadrados em DOUBLE:
    -- somada em paralelo, a ordem das parcelas mudaria o ultimo digito
    10000 * sum(p.passageiros_pagos::HUGEINT * p.passageiros_pagos) OVER mercado_no_mes
        / (sum(p.passageiros_pagos) OVER mercado_no_mes * sum(p.passageiros_pagos) OVER mercado_no_mes) AS hhi,
    p.assentos_vendidos::BIGINT AS assentos_vendidos,
    -- as somas sao exatas, em DECIMAL; o DOUBLE e so pro pandas ler
    p.receita::DOUBLE AS receita,
    (p.assentos_vendidos * m.distancia_km)::DOUBLE AS assentos_km
FROM participacao AS p
JOIN dim_mercado AS m USING (mercado)
WINDOW mercado_no_mes AS (PARTITION BY p.mes, p.mercado);

COPY (SELECT * FROM mart_mercado_mes ORDER BY mes, mercado, grupo)
TO 'dados/marts/mercado_mes.parquet' (FORMAT parquet);
