"""Testes do modelo do painel (powerbi/) contra os marts. Precisa de pyarrow;
nao precisa do Power BI nem de rede.

Uso: python teste_powerbi.py

O modelo esta em TMDL, texto: cada tabela que le um mart tem que ter as
colunas e os tipos do parquet, ler pela URL bruta do GitHub, e todo mart tem
que estar no modelo. Mart que ganha ou perde coluna quebra aqui, e nao na
primeira atualizacao de quem abre o painel.
"""
import glob
import os
import re
import unittest

import pyarrow as pa
import pyarrow.parquet as pq

RAIZ = os.path.dirname(os.path.abspath(__file__))
MODELO = os.path.join(RAIZ, "powerbi", "voos-em-numeros.SemanticModel", "definition")
MARTS = os.path.join(RAIZ, "dados", "marts")
URL = "https://raw.githubusercontent.com/ivadivad/voos-em-numeros/main/dados/marts/"


def nome_tmdl(texto):
    """'faixa de distância' -> faixa de distância; mercado -> mercado."""
    if texto.startswith("'"):
        return texto[1:-1].replace("''", "'")
    return texto


def ler_tabela(caminho):
    """{nome, colunas: {coluna: tipo}, calculadas: [...], fontes: [texto M]}"""
    with open(caminho, encoding="utf-8") as f:
        linhas = f.read().splitlines()
    # medidas numa lista, e nao num dicionario: nome repetido nao pode sumir
    tabela = {"nome": nome_tmdl(linhas[0][len("table "):].strip()), "colunas": {}, "calculadas": [], "fontes": [],
              "medidas": []}
    coluna = None
    for i, linha in enumerate(linhas):
        m = re.match(r"^\tmeasure ('(?:[^']|'')*'|[^\s=]+) =(.*)$", linha)
        if m:
            # a expressao vem na mesma linha ou nas seguintes, com recuo de tres tabs
            corpo = [m.group(2).strip()] if m.group(2).strip() else []
            for seguinte in linhas[i + 1:]:
                if not seguinte.startswith("\t\t\t"):
                    break
                corpo.append(seguinte.strip())
            tabela["medidas"].append((nome_tmdl(m.group(1)), "\n".join(corpo)))
            continue
        m = re.match(r"^\tcolumn ('(?:[^']|'')*'|[^\s=]+)( =)?", linha)
        if m:
            coluna = nome_tmdl(m.group(1))
            if m.group(2):
                tabela["calculadas"].append(coluna)
                coluna = None
            continue
        if not linha.startswith("\t\t"):
            coluna = None
        m = re.match(r"^\t\tdataType: (\w+)", linha)
        if m and coluna:
            tabela["colunas"][coluna] = m.group(1)
        if re.match(r"^\tpartition ", linha):
            # a expressao M vai ate a proxima linha com recuo de propriedade da tabela
            fonte = []
            for seguinte in linhas[i + 1:]:
                if seguinte.startswith("\t") and not seguinte.startswith("\t\t"):
                    break
                fonte.append(seguinte)
            tabela["fontes"].append("\n".join(fonte))
    return tabela


def tipo_tmdl(tipo_arrow):
    if pa.types.is_date(tipo_arrow):
        return "dateTime"
    if pa.types.is_integer(tipo_arrow):
        return "int64"
    if pa.types.is_floating(tipo_arrow) or pa.types.is_decimal(tipo_arrow):
        return "double"
    return "string"


def tabelas_do_modelo():
    return [ler_tabela(c) for c in sorted(glob.glob(os.path.join(MODELO, "tables", "*.tmdl")))]


def mart_lido(tabela):
    """O parquet que a tabela le, pelo RelativePath da consulta; None se nao le mart."""
    for fonte in tabela["fontes"]:
        m = re.search(r'RelativePath = "([^"]+)\.parquet"', fonte)
        if m:
            return m.group(1)
    return None


class TesteModeloDoPainel(unittest.TestCase):
    def test_todo_mart_esta_no_modelo(self):
        marts = {os.path.basename(c)[:-len(".parquet")] for c in glob.glob(os.path.join(MARTS, "*.parquet"))}
        lidos = {mart_lido(t) for t in tabelas_do_modelo()} - {None}
        self.assertEqual(lidos, marts)

    def test_colunas_e_tipos_iguais_aos_do_parquet(self):
        for tabela in tabelas_do_modelo():
            mart = mart_lido(tabela)
            if mart is None:
                continue
            with self.subTest(tabela=tabela["nome"]):
                esquema = pq.read_schema(os.path.join(MARTS, f"{mart}.parquet"))
                esperado = {campo.name: tipo_tmdl(campo.type) for campo in esquema}
                self.assertEqual(tabela["colunas"], esperado)

    def test_fonte_e_a_url_bruta_do_github(self):
        for tabela in tabelas_do_modelo():
            for fonte in tabela["fontes"]:
                with self.subTest(tabela=tabela["nome"]):
                    for chamada in re.findall(r'Web\.Contents\("([^"]+)"', fonte):
                        self.assertEqual(chamada, URL)
                    # letra de disco solta (C:\ ou C:/), e nao o s: de https:
                    self.assertNotRegex(fonte, r"File\.Contents|Folder\.|(?<![A-Za-z])[A-Za-z]:[\\/]")

    def test_mart_lido_pela_web(self):
        for tabela in tabelas_do_modelo():
            if mart_lido(tabela):
                with self.subTest(tabela=tabela["nome"]):
                    self.assertTrue(any("Web.Contents(" in fonte for fonte in tabela["fontes"]))

    def test_modelo_referencia_cada_tabela(self):
        with open(os.path.join(MODELO, "model.tmdl"), encoding="utf-8") as f:
            referencias = {nome_tmdl(m) for m in re.findall(r"^ref table (.+?)\s*$", f.read(), re.M)}
        self.assertEqual(referencias, {t["nome"] for t in tabelas_do_modelo()})

    def test_sem_tabela_de_data_automatica(self):
        # o calendario e o do SQL; as tabelas ocultas do Power BI duplicariam
        with open(os.path.join(MODELO, "model.tmdl"), encoding="utf-8") as f:
            self.assertIn("annotation __PBI_TimeIntelligenceEnabled = 0", f.read())


def ler_relacionamentos():
    """[{de: (tabela, coluna), para: (tabela, coluna), ativo: bool}]"""
    caminho = os.path.join(MODELO, "relationships.tmdl")
    with open(caminho, encoding="utf-8") as f:
        blocos = re.split(r"^relationship ", f.read(), flags=re.M)[1:]
    saida = []
    for bloco in blocos:
        de = re.search(r"^\tfromColumn: (.+?)\s*$", bloco, re.M).group(1)
        para = re.search(r"^\ttoColumn: (.+?)\s*$", bloco, re.M).group(1)
        saida.append({"de": tuple(nome_tmdl(p) for p in de.split(".", 1)),
                      "para": tuple(nome_tmdl(p) for p in para.split(".", 1)),
                      "ativo": not re.search(r"^\tisActive: false", bloco, re.M)})
    return saida


def valores(tabela, coluna):
    """Os valores da coluna no parquet que a tabela le."""
    mart = mart_lido(next(t for t in tabelas_do_modelo() if t["nome"] == tabela))
    return pq.read_table(os.path.join(MARTS, f"{mart}.parquet"), columns=[coluna]).column(0).to_pylist()


class TesteRelacionamentos(unittest.TestCase):
    def test_colunas_existem(self):
        colunas = {t["nome"]: t["colunas"] for t in tabelas_do_modelo()}
        for r in ler_relacionamentos():
            for tabela, coluna in (r["de"], r["para"]):
                with self.subTest(coluna=f"{tabela}.{coluna}"):
                    self.assertIn(coluna, colunas.get(tabela, {}))

    def test_do_fato_pra_dimensao(self):
        for r in ler_relacionamentos():
            with self.subTest(relacionamento=r):
                self.assertTrue(r["para"][0].startswith("dim_"))
                self.assertFalse(r["de"][0].startswith("dim_"))

    def test_lado_da_dimensao_sem_repeticao_nem_nulo(self):
        # muitos pra um: chave repetida na dimensao e o Power BI recusa o relacionamento
        for tabela, coluna in {r["para"] for r in ler_relacionamentos()}:
            with self.subTest(chave=f"{tabela}.{coluna}"):
                lista = valores(tabela, coluna)
                self.assertNotIn(None, lista)
                self.assertEqual(len(lista), len(set(lista)))

    def test_toda_chave_do_fato_existe_na_dimensao(self):
        # chave sem par vira a linha "(Em branco)" nos visuais, sem erro nenhum
        for r in ler_relacionamentos():
            with self.subTest(relacionamento=f"{'.'.join(r['de'])} -> {'.'.join(r['para'])}"):
                orfas = set(valores(*r["de"])) - {None} - set(valores(*r["para"]))
                self.assertEqual(orfas, set())

    def test_um_caminho_ativo_entre_duas_tabelas(self):
        ativos = [(r["de"][0], r["para"][0]) for r in ler_relacionamentos() if r["ativo"]]
        self.assertEqual(len(ativos), len(set(ativos)))

    def test_todo_fato_liga_em_alguma_dimensao(self):
        fatos = {t["nome"] for t in tabelas_do_modelo() if mart_lido(t) and not t["nome"].startswith("dim_")}
        self.assertEqual({r["de"][0] for r in ler_relacionamentos()}, fatos)


def referencias(expressao):
    """(colunas citadas como tabela[coluna], medidas citadas como [medida])"""
    sem_texto = re.sub(r'"(?:[^"]|"")*"', '""', expressao)
    colunas = [(nome_tmdl(t), c) for t, c in
               re.findall(r"(?<![\w'\]])('(?:[^']|'')+'|[A-Za-z_]\w*)\[([^\]]+)\]", sem_texto)]
    medidas = re.findall(r"(?<![\w'\]])\[([^\]]+)\]", sem_texto)
    return colunas, medidas


class TesteMedidas(unittest.TestCase):
    def test_medida_cita_coluna_e_medida_que_existem(self):
        tabelas = tabelas_do_modelo()
        colunas = {(t["nome"], c) for t in tabelas for c in list(t["colunas"]) + t["calculadas"]}
        medidas = {nome for t in tabelas for nome, _ in t["medidas"]}
        for tabela in tabelas:
            for nome, expressao in tabela["medidas"]:
                citadas, chamadas = referencias(expressao)
                with self.subTest(medida=nome):
                    self.assertTrue(expressao)
                    self.assertEqual([c for c in citadas if c not in colunas], [])
                    self.assertEqual([m for m in chamadas if m not in medidas], [])

    def test_nome_de_medida_unico(self):
        nomes = [nome for t in tabelas_do_modelo() for nome, _ in t["medidas"]]
        self.assertEqual(len(nomes), len(set(nomes)))

    def test_leitor_de_referencias(self):
        colunas, medidas = referencias("DIVIDE([Receita], SUM('Minha tabela'[a b])) + t[c] + \"[x]\"")
        self.assertEqual(colunas, [("Minha tabela", "a b"), ("t", "c")])
        self.assertEqual(medidas, ["Receita"])


class TesteLeitorDeTmdl(unittest.TestCase):
    def test_le_colunas_calculadas_e_nomes_com_aspas(self):
        texto = ("table 'Minha tabela'\n\tlineageTag: x\n\n\tcolumn a\n\t\tdataType: int64\n\n"
                 "\tcolumn 'faixa de distância' = \"x\"\n\t\tdataType: string\n\n"
                 "\tpartition 'Minha tabela' = m\n\t\tmode: import\n\t\tsource =\n\t\t\t\tlet\n"
                 '\t\t\t\t    Fonte = Web.Contents("u", [RelativePath = "t.parquet"])\n\t\t\t\tin\n\t\t\t\t    Fonte\n\n'
                 "\tannotation PBI_ResultType = Table\n")
        import tempfile
        with tempfile.TemporaryDirectory() as pasta:
            caminho = os.path.join(pasta, "t.tmdl")
            with open(caminho, "w", encoding="utf-8") as f:
                f.write(texto)
            tabela = ler_tabela(caminho)
        self.assertEqual(tabela["nome"], "Minha tabela")
        self.assertEqual(tabela["colunas"], {"a": "int64"})
        self.assertEqual(tabela["calculadas"], ["faixa de distância"])
        self.assertEqual(mart_lido(tabela), "t")
        self.assertNotIn("annotation", tabela["fontes"][0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
