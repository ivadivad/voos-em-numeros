"""Testes do executor dos .sql. Precisa de duckdb (pip install -r
requirements.txt); nao precisa dos brutos: cada teste escreve seus .sql de
mentira.

Uso: python teste_construir.py
"""
import io
import os
import shutil
import tempfile
import unittest
from unittest.mock import patch

import duckdb

import construir


class ComPastaTemporaria(unittest.TestCase):
    """Cada teste escreve .sql numa pasta temporaria, apagada no fim, e
    constroi um banco nela."""

    def setUp(self):
        self.pasta = tempfile.mkdtemp()
        self.sql = os.path.join(self.pasta, "sql")
        os.makedirs(self.sql)
        self.banco = os.path.join(self.pasta, "teste.duckdb")
        self.saida = patch("sys.stdout", new_callable=io.StringIO)
        self.stdout = self.saida.start()

    def tearDown(self):
        self.saida.stop()
        shutil.rmtree(self.pasta)

    def escrever(self, nome, sql):
        caminho = os.path.join(self.sql, nome)
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        with open(caminho, "w", encoding="utf-8") as arquivo:
            arquivo.write(sql)

    def construir(self):
        return construir.construir(self.sql, self.banco)

    def consultar(self, sql):
        with duckdb.connect(self.banco) as con:
            return con.execute(sql).fetchall()


class TesteOrdem(ComPastaTemporaria):
    def test_roda_em_ordem_alfabetica(self):
        # escritos fora de ordem: quem manda e o nome do arquivo
        self.escrever("20_c.sql", "INSERT INTO log VALUES ('c');")
        self.escrever("00_a.sql", "CREATE TABLE log (n VARCHAR); INSERT INTO log VALUES ('a');")
        self.escrever("10_b.sql", "INSERT INTO log VALUES ('b');")
        self.assertEqual(self.construir(), 0)
        self.assertEqual(self.consultar("SELECT list(n ORDER BY rowid) FROM log"), [(["a", "b", "c"],)])

    def test_arquivo_com_varios_comandos(self):
        self.escrever("00_a.sql", "CREATE TABLE t (x INTEGER);\nINSERT INTO t VALUES (1);\nINSERT INTO t VALUES (2);\n")
        self.assertEqual(self.construir(), 0)
        self.assertEqual(self.consultar("SELECT sum(x) FROM t"), [(3,)])

    def test_so_roda_os_sql_da_propria_pasta(self):
        # os testes, em sql/testes/, nao sao modelos; e nem todo arquivo e .sql
        self.escrever("00_a.sql", "CREATE TABLE t (x INTEGER);")
        self.escrever("leia-me.txt", "isto nao e sql")
        self.escrever(os.path.join("testes", "t.sql"), "SELECT * FROM nao_existe;")
        self.assertEqual(self.construir(), 0)

    def test_mostra_o_tempo_de_cada_arquivo(self):
        self.escrever("00_a.sql", "SELECT 1;")
        self.escrever("10_b.sql", "SELECT 2;")
        self.construir()
        linhas = self.stdout.getvalue().splitlines()
        self.assertRegex(linhas[0], r"^00_a\.sql +\d+\.\ds$")
        self.assertRegex(linhas[1], r"^10_b\.sql +\d+\.\ds$")


class TesteParada(ComPastaTemporaria):
    def test_para_no_primeiro_erro(self):
        self.escrever("00_a.sql", "CREATE TABLE log (n VARCHAR);")
        self.escrever("10_b.sql", "SELECT * FROM nao_existe;")
        self.escrever("20_c.sql", "INSERT INTO log VALUES ('c');")
        self.assertEqual(self.construir(), 1)
        self.assertEqual(self.consultar("SELECT count(*) FROM log"), [(0,)])  # o 20 nao rodou
        saida = self.stdout.getvalue()
        self.assertIn("10_b.sql", saida)
        self.assertIn("nao_existe", saida)  # a mensagem do DuckDB aparece
        self.assertNotIn("20_c.sql", saida)

    def test_erro_de_sintaxe_tambem_para(self):
        # o DuckDB levanta outra classe de excecao pra erro de sintaxe
        self.escrever("00_a.sql", "CREATE TABLE log (n VARCHAR);")
        self.escrever("10_b.sql", "SELEC 1;")
        self.escrever("20_c.sql", "INSERT INTO log VALUES ('c');")
        self.assertEqual(self.construir(), 1)
        self.assertEqual(self.consultar("SELECT count(*) FROM log"), [(0,)])

    def test_pasta_sem_sql_sai_com_erro(self):
        # rodada vazia nao termina verde (licao do MED)
        self.assertEqual(self.construir(), 1)
        self.assertIn("nenhum .sql", self.stdout.getvalue())


class TesteDoZero(ComPastaTemporaria):
    def test_cada_rodada_parte_do_banco_vazio(self):
        # tabela que saiu dos .sql nao pode sobrar no banco
        self.escrever("00_a.sql", "CREATE TABLE velha (x INTEGER);")
        self.construir()
        os.remove(os.path.join(self.sql, "00_a.sql"))
        self.escrever("00_b.sql", "CREATE TABLE nova (x INTEGER);")
        self.assertEqual(self.construir(), 0)
        self.assertEqual(self.consultar("SELECT table_name FROM information_schema.tables"), [("nova",)])

    @patch("construir.apagar_banco", side_effect=PermissionError)
    def test_banco_aberto_em_outro_programa(self, _):
        self.escrever("00_a.sql", "SELECT 1;")
        self.assertEqual(self.construir(), 1)
        self.assertIn("aberto em outro programa", self.stdout.getvalue())


class TesteMain(unittest.TestCase):
    @patch("construir.construir")
    def test_sem_brutos_avisa_pra_coletar_antes(self, construir_):
        with patch("construir.PASTA_BRUTOS", os.path.join("nao", "existe")), \
                patch("sys.stdout", new_callable=io.StringIO) as saida:
            self.assertEqual(construir.main([]), 1)
        construir_.assert_not_called()
        self.assertIn("coletar.py", saida.getvalue())

    @patch("construir.construir", return_value=0)
    def test_com_brutos_constroi(self, construir_):
        with patch("construir.PASTA_BRUTOS", os.path.dirname(os.path.abspath(__file__))):
            self.assertEqual(construir.main([]), 0)
        construir_.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
