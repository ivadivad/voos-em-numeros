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
    tabela = {"nome": nome_tmdl(linhas[0][len("table "):].strip()), "colunas": {}, "calculadas": [], "fontes": []}
    coluna = None
    for i, linha in enumerate(linhas):
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
