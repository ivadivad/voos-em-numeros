-- Fato da oferta e da demanda: um registro por grupo, mercado, mes e grupo
-- de voo, com passageiros, assentos, decolagens, distancia voada, ASK e RPK
-- da base estatistica. E dele que sai a participacao de cada grupo num
-- mercado, e dela o HHI: por passageiros pagos, que contam todo mundo que
-- voou, e nao pelos assentos das tarifas, que deixam de fora milhas e
-- tarifa corporativa.
--
-- O passageiro aqui e o do voo, nao o da viagem: quem troca de aviao conta
-- uma vez em cada voo (ver DICIONARIO.md). O mes e o do voo.
--
-- Duas decisoes:
--
-- 1. O grupo de voo (REGULAR, NAO REGULAR, IMPRODUTIVO) fica no grao, alem
--    do grupo, do mercado e do mes que o plano previa. A staging deixou pra
--    depois qual entra em cada conta, e o fato continua sem decidir: o
--    voo fretado de um grupo pode ou nao contar na fatia dele, e a escolha
--    tem que ficar visivel na analise.
--
-- 2. Fica de fora o par de aeroportos da mesma cidade, que nao forma
--    mercado. Na coleta de 13/10/2026, sao 428.410 passageiros pagos,
--    94,5% deles do grupo improdutivo com origem igual ao destino: o voo
--    que voltou pra onde saiu. Do regular, saem 18.671 (0,003%).
--
-- Nulo na staging quer dizer "nao se aplica" (par so de embarque e
-- desembarque, sem perna direta, nao tem assento). No fato, a soma do
-- grupo vira zero: o par de cidades nao teve assento oferecido em voo
-- direto.
CREATE OR REPLACE TABLE fato_oferta AS
SELECT
    e.mes,
    g.grupo,
    chave_mercado(o.cidade, d.cidade) AS mercado,
    e.grupo_de_voo,
    coalesce(sum(e.passageiros_pagos), 0)::BIGINT AS passageiros_pagos,
    coalesce(sum(e.passageiros_gratis), 0)::BIGINT AS passageiros_gratis,
    coalesce(sum(e.assentos), 0)::BIGINT AS assentos,
    coalesce(sum(e.decolagens), 0)::BIGINT AS decolagens,
    coalesce(sum(e.distancia_voada_km), 0)::BIGINT AS distancia_voada_km,
    coalesce(sum(e.ask), 0)::BIGINT AS ask,
    coalesce(sum(e.rpk), 0)::BIGINT AS rpk
FROM stg_estatisticas AS e
LEFT JOIN empresa_grupo AS g ON g.empresa = e.empresa AND no_periodo(e.mes, g.desde, g.ate)
LEFT JOIN dim_aeroporto AS o ON o.icao = e.origem
LEFT JOIN dim_aeroporto AS d ON d.icao = e.destino
WHERE NOT coalesce(o.cidade = d.cidade, false)
GROUP BY ALL;
