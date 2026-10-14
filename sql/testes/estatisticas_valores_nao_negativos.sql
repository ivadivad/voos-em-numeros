-- Passageiros, assentos, decolagens, distancia, ASK e RPK nao podem ser
-- negativos.
SELECT *
FROM stg_estatisticas
WHERE passageiros_pagos < 0 OR passageiros_gratis < 0 OR assentos < 0 OR decolagens < 0
   OR distancia_voada_km < 0 OR ask < 0 OR rpk < 0;
