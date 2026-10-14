-- A leitura das tarifas e por posicao (00_brutos.sql): supoe que todo
-- arquivo tem as sete colunas na mesma ordem, com um dos cinco cabecalhos
-- conhecidos (ver DICIONARIO.md). Devolve o arquivo com outro cabecalho, ou
-- com mais de uma linha que parece cabecalho.
--
-- O acento sai antes de comparar: a versao C e UTF-8 com BOM, e lida como
-- Latin-1 o acento vira dois caracteres estranhos. A coluna sem nome da
-- versao D vem nula e o concat_ws pula, o que a deixa igual a B.
WITH linhas AS (
    SELECT
        parse_filename(filename) AS arquivo,
        -- dado comeca pelo ano, ou pelo numero da linha na versao D
        c1 IS NULL OR NOT regexp_full_match(c1, '\d+') AS e_cabecalho,
        regexp_replace(concat_ws(';', c1, c2, c3, c4, c5, c6, c7, c8), '[^\x00-\x7F]', '', 'g') AS texto
    FROM read_csv('dados/brutos/tarifas/*.csv',
        auto_detect = false, header = false,
        delim = ';', quote = '"', escape = '"', encoding = 'latin-1', null_padding = true,
        columns = {'c1': 'VARCHAR', 'c2': 'VARCHAR', 'c3': 'VARCHAR', 'c4': 'VARCHAR',
                   'c5': 'VARCHAR', 'c6': 'VARCHAR', 'c7': 'VARCHAR', 'c8': 'VARCHAR'},
        filename = true)
)
SELECT
    arquivo,
    count(*) FILTER (WHERE e_cabecalho) AS linhas_de_cabecalho,
    any_value(texto) FILTER (WHERE e_cabecalho) AS cabecalho
FROM linhas
GROUP BY arquivo
HAVING linhas_de_cabecalho <> 1
    OR cabecalho NOT IN (
        'ANO;MES;EMPRESA;ORIGEM;DESTINO;TARIFA;ASSENTOS',
        'Ano de Referncia;Ms de Referncia;ICAO Empresa Area;ICAO Aerdromo Origem;'
            || 'ICAO Aerdromo Destino;Tarifa-N;Assentos Comercializados',
        'nr_ano_referencia;nr_mes_referencia;sg_empresa_icao;sg_icao_origem;'
            || 'sg_icao_destino;nr_tarifa;nr_assentos'
    );
