-- Valor preenchido no bruto que o TRY_CAST nao converteu. Na staging o nulo
-- tambem quer dizer "nao se aplica" (linha so da basica ou so da
-- combinada), entao a conferencia e no bruto, em todas as linhas.
SELECT *
FROM bruto_estatisticas
WHERE TRY_CAST(ano || '-' || lpad(mes, 2, '0') || '-01' AS DATE) IS NULL
   OR (passageiros_pagos IS NOT NULL AND TRY_CAST(passageiros_pagos AS BIGINT) IS NULL)
   OR (passageiros_gratis IS NOT NULL AND TRY_CAST(passageiros_gratis AS BIGINT) IS NULL)
   OR (assentos IS NOT NULL AND TRY_CAST(assentos AS BIGINT) IS NULL)
   OR (decolagens IS NOT NULL AND TRY_CAST(decolagens AS BIGINT) IS NULL)
   OR (distancia_voada_km IS NOT NULL AND TRY_CAST(distancia_voada_km AS BIGINT) IS NULL)
   OR (ask IS NOT NULL AND TRY_CAST(ask AS BIGINT) IS NULL)
   OR (rpk IS NOT NULL AND TRY_CAST(rpk AS BIGINT) IS NULL);
