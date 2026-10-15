-- Distancia em linha reta entre dois pontos, em km, pela formula de
-- haversine: o caminho mais curto sobre uma esfera de raio 6.371 km.
--
-- E a distancia que a ANAC usa no yield, "o valor medio pago por
-- quilometro entre a origem e o destino do passageiro, independentemente de
-- escalas ou conexoes" (Relatorio de Tarifas Aereas Domesticas, 1o
-- trimestre de 2018). Nos pares com voo direto, bate com a distancia por
-- decolagem que a ANAC publica na base estatistica, e o teste
-- testes/distancia_bate_com_a_anac.sql confere.
CREATE OR REPLACE MACRO distancia_km(lat1, lon1, lat2, lon2) AS
    2 * 6371 * asin(sqrt(
        pow(sin(radians(lat2 - lat1) / 2), 2)
        + cos(radians(lat1)) * cos(radians(lat2)) * pow(sin(radians(lon2 - lon1) / 2), 2)
    ));
