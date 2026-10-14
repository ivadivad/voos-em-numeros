-- O VRA tambem e lido por posicao (00_brutos.sql), entao o nome das colunas
-- nao e conferido na leitura. Este teste confere: devolve o arquivo cujo
-- cabecalho, na segunda linha, nao e o de sempre.
WITH linhas AS (
    SELECT
        parse_filename(filename) AS arquivo,
        -- linha de dado comeca pela sigla da empresa
        NOT regexp_full_match(c1, '[A-Z0-9]{2,4}') AS e_cabecalho,
        concat_ws(';', c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12) AS texto
    FROM read_csv('dados/brutos/vra/*.csv',
        auto_detect = false, header = false, skip = 1,
        delim = ';', quote = '"', escape = '"', encoding = 'utf-8',
        columns = {'c1': 'VARCHAR', 'c2': 'VARCHAR', 'c3': 'VARCHAR', 'c4': 'VARCHAR',
                   'c5': 'VARCHAR', 'c6': 'VARCHAR', 'c7': 'VARCHAR', 'c8': 'VARCHAR',
                   'c9': 'VARCHAR', 'c10': 'VARCHAR', 'c11': 'VARCHAR', 'c12': 'VARCHAR'},
        filename = true)
)
SELECT
    arquivo,
    count(*) FILTER (WHERE e_cabecalho) AS linhas_de_cabecalho,
    any_value(texto) FILTER (WHERE e_cabecalho) AS cabecalho
FROM linhas
GROUP BY arquivo
HAVING linhas_de_cabecalho <> 1
    OR cabecalho <> 'ICAO Empresa Aérea;Número Voo;Código Autorização (DI);Código Tipo Linha;'
                    || 'ICAO Aeródromo Origem;ICAO Aeródromo Destino;Partida Prevista;Partida Real;'
                    || 'Chegada Prevista;Chegada Real;Situação Voo;Código Justificativa';
