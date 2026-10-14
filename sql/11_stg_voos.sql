-- Voos domesticos regulares de passageiros, padronizados: uma linha por
-- etapa de voo (a decolagem e o pouso seguinte), com os horarios previstos e
-- realizados, o atraso na chegada e se o voo foi cancelado.
--
-- Quatro decisoes, as tres primeiras na ordem em que sao aplicadas (ver
-- DICIONARIO.md):
--
-- 1. Fev e mar/2020 ficam fora. Nos arquivos atuais, todas as linhas desses
--    dois meses trazem o texto 'Microsoft.SqlServer.Dts.Pipeline.BlobColumn'
--    no lugar dos horarios e da situacao. O corte e pelo conteudo, nao pelo
--    mes: se a ANAC consertar os arquivos, os dois meses voltam sozinhos.
--
-- 2. So voo domestico regular de passageiros: tipo de linha N (e R e H, que
--    existiam ate mar/2020) e Digito Identificador do grupo regular, 0 ou 4.
--    O C, tambem regular pela descricao de variaveis, nao aparece nos dados.
--
-- 3. Uma linha por voo. O voo e a empresa, o numero, a origem, o destino e a
--    partida prevista (ou a real, nas etapas nao planejadas, que nao tem
--    prevista). Duas situacoes repetem um voo:
--    - copias exatas, inclusive do mesmo voo em dois arquivos: conta uma vez;
--    - registros que se contradizem, quase todos de 2019: o mesmo voo como
--      CANCELADO e como REALIZADO, ou realizado duas vezes com horarios
--      diferentes. Fica o realizado, que tem horario real como evidencia, e
--      entre dois realizados, o que partiu primeiro.
--
-- 4. Mais de dois dias entre a chegada prevista e a real nao e atraso: e data
--    digitada errada (o ano, o mes, ou o dia e o mes trocados). O voo fica,
--    com os horarios publicados, e o atraso fica nulo. Ate dois dias, fica:
--    ha voos antecipados em horas, que partiram antes de verdade, e voos
--    adiados ou antecipados um dia, que nao da pra separar de uma data com um
--    dia de diferenca.
CREATE OR REPLACE MACRO horario(texto) AS TRY_CAST(nullif(texto, 'null') AS TIMESTAMP);

CREATE OR REPLACE TABLE stg_voos AS
WITH convertido AS (
    SELECT
        upper(trim(empresa)) AS empresa,
        trim(voo) AS voo,  -- texto: o zero a esquerda faz parte (0084)
        upper(trim(origem)) AS origem,
        upper(trim(destino)) AS destino,
        di,
        tipo_linha,
        horario(partida_prevista) AS partida_prevista,
        horario(partida_real) AS partida_real,
        horario(chegada_prevista) AS chegada_prevista,
        horario(chegada_real) AS chegada_real,
        situacao,
        justificativa,
        arquivo
    FROM bruto_vra
    WHERE NOT list_contains([partida_prevista, partida_real, chegada_prevista, chegada_real, situacao],
                            'Microsoft.SqlServer.Dts.Pipeline.BlobColumn')
      AND di IN ('0', '4')
      AND (tipo_linha = 'N' OR (tipo_linha IN ('R', 'H') AND arquivo <= '202003.csv'))
)
SELECT
    empresa,
    voo,
    origem,
    destino,
    di,
    partida_prevista,
    partida_real,
    chegada_prevista,
    chegada_real,
    situacao,
    situacao = 'CANCELADO' AS cancelado,
    -- minutos, negativo quando chegou antes; so pra quem tem os dois horarios
    CASE WHEN abs(epoch(chegada_real) - epoch(chegada_prevista)) <= 2 * 24 * 60 * 60
         THEN CAST(round((epoch(chegada_real) - epoch(chegada_prevista)) / 60) AS INTEGER)
    END AS atraso_chegada_min,
    arquivo
FROM convertido
QUALIFY row_number() OVER (
    PARTITION BY empresa, voo, origem, destino, coalesce(partida_prevista, partida_real)
    ORDER BY situacao = 'REALIZADO' DESC, partida_real, chegada_real, chegada_prevista,
             situacao, justificativa, arquivo
) = 1;
