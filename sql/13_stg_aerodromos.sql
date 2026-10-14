-- Aerodromos padronizados: uma linha por codigo OACI, juntando a lista
-- publica e a de privados, com a cidade, a UF em sigla e as coordenadas em
-- graus decimais.
--
-- As coordenadas saem da conversao do grau, minuto e segundo, e nao do
-- decimal que a ANAC publica junto: na lista de privados o decimal descarta
-- a fracao de segundo (19°33'33,46"S vira -19,559167, que e 33,00"). O
-- decimal publicado serve de conferencia, num teste.
--
-- Defeitos da lista de privados tratados aqui (ver DICIONARIO.md):
-- - 23 linhas sem codigo OACI ficam de fora;
-- - SD09, SS3G e SS7V aparecem em dois aerodromos diferentes cada um. Nao
--   da pra saber qual e qual, e nenhum dos tres esta nas outras bases:
--   ficam de fora;
-- - coordenada fora do Brasil vira nula. E so a SJ1Z, com longitude a leste
--   de Greenwich.
CREATE OR REPLACE MACRO graus_decimais(gms) AS (
    WITH partes AS (
        -- 23°37'34"S ou 019°33'33,46"S; texto fora desse formato da nulo
        SELECT regexp_extract(gms, '^(\d+)°(\d+)''(\d+(?:[.,]\d+)?)"([NSEW])$',
                              ['graus', 'minutos', 'segundos', 'hemisferio']) AS p
    )
    SELECT CASE WHEN p.hemisferio IN ('S', 'W') THEN -1 WHEN p.hemisferio IN ('N', 'E') THEN 1 END
           * (TRY_CAST(p.graus AS DOUBLE)
              + TRY_CAST(p.minutos AS DOUBLE) / 60
              + TRY_CAST(replace(p.segundos, ',', '.') AS DOUBLE) / 3600)
    FROM partes
);

CREATE OR REPLACE TABLE stg_aerodromos AS
WITH uf(nome, sigla) AS (
    -- a lista publica traz a UF por extenso; a de privados, em sigla
    VALUES ('Acre', 'AC'), ('Alagoas', 'AL'), ('Amapá', 'AP'), ('Amazonas', 'AM'),
           ('Bahia', 'BA'), ('Ceará', 'CE'), ('Distrito Federal', 'DF'),
           ('Espírito Santo', 'ES'), ('Goiás', 'GO'), ('Maranhão', 'MA'),
           ('Mato Grosso', 'MT'), ('Mato Grosso do Sul', 'MS'), ('Minas Gerais', 'MG'),
           ('Pará', 'PA'), ('Paraíba', 'PB'), ('Paraná', 'PR'), ('Pernambuco', 'PE'),
           ('Piauí', 'PI'), ('Rio de Janeiro', 'RJ'), ('Rio Grande do Norte', 'RN'),
           ('Rio Grande do Sul', 'RS'), ('Rondônia', 'RO'), ('Roraima', 'RR'),
           ('Santa Catarina', 'SC'), ('São Paulo', 'SP'), ('Sergipe', 'SE'),
           ('Tocantins', 'TO')
),
publicos AS (
    SELECT
        upper(trim(a.icao)) AS icao,
        trim(a.nome) AS nome,
        -- a cidade atendida, nao a do ponto de referencia: Guarulhos fica
        -- em Guarulhos, embora o municipio calculado diga Sao Paulo
        trim(coalesce(a.municipio_servido, a.municipio)) AS municipio,
        uf.sigla AS uf,
        graus_decimais(trim(a.latitude_gms)) AS latitude,
        graus_decimais(trim(a.longitude_gms)) AS longitude,
        'publica' AS lista
    FROM bruto_aerodromos_publicos AS a
    LEFT JOIN uf ON uf.nome = trim(coalesce(a.uf_servido, a.uf))
),
privados AS (
    SELECT
        upper(trim(icao)) AS icao,
        trim(nome) AS nome,
        trim(municipio) AS municipio,
        upper(trim(uf)) AS uf,
        graus_decimais(trim(latitude_gms)) AS latitude,
        graus_decimais(trim(longitude_gms)) AS longitude,
        'privada' AS lista
    FROM bruto_aerodromos_privados
    WHERE trim(coalesce(icao, '')) <> ''
    QUALIFY count(*) OVER (PARTITION BY upper(trim(icao))) = 1
),
juntos AS (
    SELECT * FROM publicos
    UNION ALL
    -- codigo nas duas listas fica com a publica (hoje nao ha nenhum)
    SELECT * FROM privados WHERE icao NOT IN (SELECT icao FROM publicos)
)
SELECT
    icao,
    nome,
    municipio,
    uf,
    -- caixa que contem o Brasil, ilhas oceanicas incluidas
    CASE WHEN latitude BETWEEN -34 AND 6 AND longitude BETWEEN -74 AND -28 THEN latitude END AS latitude,
    CASE WHEN latitude BETWEEN -34 AND 6 AND longitude BETWEEN -74 AND -28 THEN longitude END AS longitude,
    lista
FROM juntos;
