-- Atraso plausivel, em duas conferencias.
--
-- A staging deixa nulo o atraso de mais de dois dias, que e data digitada
-- errada: 8 voos na coleta de 13/10/2026. Centenas seriam erro da leitura,
-- nao da ANAC (um horario lido com dia e mes invertidos, por exemplo).
--
-- E a mediana do atraso de cada mes fica perto de zero: de -13 min
-- (abr/2020) a 0 na mesma coleta. Fuso ou coluna trocada deslocariam o mes
-- inteiro.
SELECT 'atraso nulo por data trocada' AS problema, NULL::DATE AS mes, count(*) AS valor
FROM stg_voos
WHERE chegada_prevista IS NOT NULL AND chegada_real IS NOT NULL AND atraso_chegada_min IS NULL
HAVING count(*) > 100
UNION ALL
SELECT 'mediana do mes longe de zero', date_trunc('month', chegada_prevista)::DATE, median(atraso_chegada_min)
FROM stg_voos
WHERE atraso_chegada_min IS NOT NULL
GROUP BY 2
HAVING median(atraso_chegada_min) NOT BETWEEN -30 AND 30;
