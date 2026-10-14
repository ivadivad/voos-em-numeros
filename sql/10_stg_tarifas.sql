-- Tarifas padronizadas: uma linha por valor de tarifa vendido por uma
-- empresa, de uma origem para um destino, num mes.
--
-- Tres pontos dos metadados que valem pra tudo que vem depois (ver
-- DICIONARIO.md): o mes e o da venda, nao o do voo; a empresa e a que
-- vendeu; origem e destino sao os do passageiro, com conexao e tudo.
--
-- Toda conversao e TRY_CAST: o que nao converter vira nulo, e o teste
-- testes/tarifas_sem_nulo.sql aponta a linha, em vez de a construcao parar
-- no primeiro valor estranho ou de ele sumir da media.
CREATE OR REPLACE TABLE stg_tarifas AS
SELECT
    -- mes da venda, como data no dia 1; o arquivo traz o mes sem zero (8)
    TRY_CAST(ano || '-' || lpad(mes, 2, '0') || '-01' AS DATE) AS mes,
    upper(trim(empresa)) AS empresa,
    upper(trim(origem)) AS origem,
    upper(trim(destino)) AS destino,
    -- virgula decimal em 80 arquivos, ponto em 12, e nenhum separador de
    -- milhar: trocar a virgula por ponto serve aos dois formatos
    TRY_CAST(replace(tarifa, ',', '.') AS DECIMAL(10, 2)) AS tarifa,
    TRY_CAST(assentos AS INTEGER) AS assentos,
    arquivo
FROM bruto_tarifas;
