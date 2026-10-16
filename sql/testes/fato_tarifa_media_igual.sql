-- A tarifa media de cada mes, calculada no fato, e a mesma da stg_tarifas,
-- no centavo. E a media que a etapa 4 conferiu com a ANAC (R$ 776,87 em
-- ago/2026, por exemplo): agregar por grupo e mercado nao pode muda-la. A
-- venda dentro da mesma cidade, que sai do fato, e pouca demais pra mexer
-- no centavo; se um dia mexer, o teste avisa.
WITH fato AS (
    SELECT mes, sum(tarifa * assentos) / sum(assentos) AS media
    FROM fato_tarifa
    GROUP BY mes
),
staging AS (
    SELECT mes, sum(tarifa * assentos) / sum(assentos) AS media
    FROM stg_tarifas
    GROUP BY mes
)
SELECT mes, round(s.media, 4) AS media_staging, round(f.media, 4) AS media_fato
FROM staging AS s
FULL JOIN fato AS f USING (mes)
WHERE abs(s.media - f.media) >= 0.005 OR s.media IS NULL OR f.media IS NULL;
