-- Juntando dois grupos, a variacao do HHI tem formula fechada: duas vezes o
-- produto das participacoes, "∆HHI = 2 * S1 * S2" no guia do CADE (secao
-- 2.4.2), com as participacoes em pontos percentuais. Com elas em fracao,
-- como no mart, sao 20.000 vezes o produto. O mart faz a conta completa (o
-- HHI depois menos o HHI antes, cada um pelas somas dos passageiros), e as
-- duas tem que dar o mesmo em todo mercado das duas janelas. Diferenca
-- quer dizer grupo simulado errado, participacao errada ou um terceiro
-- grupo dentro da fusao.
SELECT janela, mercado, participacao_azul, participacao_gol, delta_hhi,
       20000 * participacao_azul * participacao_gol AS pela_formula
FROM mart_fusao
WHERE abs(delta_hhi - 20000 * participacao_azul * participacao_gol) > 1e-6
   OR participacao_azul NOT BETWEEN 0 AND 1
   OR participacao_gol NOT BETWEEN 0 AND 1
   OR participacao_azul + participacao_gol > 1 + 1e-9;
