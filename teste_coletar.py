"""Testes do coletor. So biblioteca padrao, sem tocar na rede.

Uso: python teste_coletar.py
"""
import http.client
import io
import unittest
from unittest.mock import MagicMock, patch
from urllib.error import HTTPError, URLError

import coletar


def resposta(status, corpo):
    """Imita o objeto que urlopen devolve, usado com `with`."""
    r = MagicMock()
    r.status = status
    r.read.return_value = corpo
    r.__enter__.return_value = r
    return r


def erro_http(codigo):
    return HTTPError("https://exemplo", codigo, "erro", {}, io.BytesIO(b"<html>erro</html>"))


class TesteFontes(unittest.TestCase):
    def test_as_quatro_bases(self):
        self.assertEqual(sorted(coletar.FONTES), ["aerodromos", "estatisticas", "tarifas", "vra"])

    def test_toda_base_diz_como_o_arquivo_chega(self):
        for base, fonte in coletar.FONTES.items():
            with self.subTest(base=base):
                self.assertIn(fonte["tipo"], ("mensal", "fixo"))
                self.assertEqual(fonte["separador"], ";")
                self.assertIn(fonte["encoding"], ("latin-1", "utf-8-sig"))
                self.assertIn(fonte["linhas_cabecalho"], (1, 2))

    def test_base_mensal_tem_padrao_de_url_e_listagem(self):
        for base, fonte in coletar.FONTES.items():
            if fonte["tipo"] != "mensal":
                continue
            with self.subTest(base=base):
                self.assertIn("{ano}", fonte["url"])
                self.assertIn("{mes", fonte["url"])
                self.assertTrue(fonte["listagem"].startswith("https://"))
                self.assertEqual(fonte["desde"], 201901)

    def test_base_fixa_tem_nome_e_url_de_cada_arquivo(self):
        for base, fonte in coletar.FONTES.items():
            if fonte["tipo"] != "fixo":
                continue
            with self.subTest(base=base):
                self.assertTrue(fonte["arquivos"])
                for nome, url in fonte["arquivos"].items():
                    self.assertTrue(url.startswith("https://"))
                    self.assertTrue(url.endswith("/" + nome))

    def test_pasta_do_vra_tem_o_mes_por_extenso_com_acento(self):
        # a pasta de marco e "03 - Março": sem o cedilha, a URL da 404
        self.assertEqual(len(coletar.MESES), 12)
        self.assertEqual(coletar.MESES[2], "Março")


@patch("coletar.urllib.request.urlopen")
class TesteBaixar(unittest.TestCase):
    def test_200_devolve_os_bytes(self, urlopen):
        urlopen.return_value = resposta(200, b"ANO;MES\r\n2019;1\r\n")
        self.assertEqual(coletar.baixar("https://exemplo/x.csv"), (200, b"ANO;MES\r\n2019;1\r\n"))

    def test_404_devolve_o_codigo(self, urlopen):
        urlopen.side_effect = erro_http(404)
        self.assertEqual(coletar.baixar("https://exemplo/x.csv"), (404, b""))

    def test_403_devolve_o_codigo(self, urlopen):
        # o que o gov.br responde ao User-Agent padrao do urllib
        urlopen.side_effect = erro_http(403)
        self.assertEqual(coletar.baixar("https://exemplo/x.csv"), (403, b""))

    def test_500_devolve_o_codigo(self, urlopen):
        urlopen.side_effect = erro_http(500)
        self.assertEqual(coletar.baixar("https://exemplo/x.csv"), (500, b""))

    def test_timeout_nao_levanta_excecao(self, urlopen):
        urlopen.side_effect = URLError(TimeoutError("timed out"))
        self.assertEqual(coletar.baixar("https://exemplo/x.csv"), (None, b""))

    def test_timeout_no_meio_da_leitura(self, urlopen):
        r = resposta(200, b"")
        r.read.side_effect = TimeoutError("timed out")
        urlopen.return_value = r
        self.assertEqual(coletar.baixar("https://exemplo/x.csv"), (None, b""))

    def test_conexao_derrubada_pelo_servidor(self, urlopen):
        # WinError 10054, visto na ANAC durante a etapa 1
        urlopen.side_effect = ConnectionResetError(10054, "conexao cancelada pelo host remoto")
        self.assertEqual(coletar.baixar("https://exemplo/x.csv"), (None, b""))

    def test_arquivo_cortado_no_meio_nao_vira_200(self, urlopen):
        # IncompleteRead nao e OSError: sem tratar, derrubaria o coletor; e
        # tratar como 200 gravaria um arquivo pela metade
        r = resposta(200, b"")
        r.read.side_effect = http.client.IncompleteRead(b"ANO;M", 1000)
        urlopen.return_value = r
        self.assertEqual(coletar.baixar("https://exemplo/x.csv"), (None, b""))

    def test_manda_o_user_agent_do_projeto(self, urlopen):
        urlopen.return_value = resposta(200, b"")
        coletar.baixar("https://exemplo/x.csv")
        pedido = urlopen.call_args[0][0]
        self.assertEqual(pedido.get_header("User-agent"), coletar.USER_AGENT)
        self.assertNotIn("Python-urllib", coletar.USER_AGENT)

    def test_codifica_espaco_parentese_e_acento(self, urlopen):
        urlopen.return_value = resposta(200, b"")
        coletar.baixar("https://exemplo/2026/202605 (1).CSV")
        self.assertEqual(urlopen.call_args[0][0].full_url, "https://exemplo/2026/202605%20%281%29.CSV")
        coletar.baixar("https://exemplo/2020/03 - Março/")
        self.assertEqual(urlopen.call_args[0][0].full_url, "https://exemplo/2020/03%20-%20Mar%C3%A7o/")

    def test_url_ja_codificada_e_query_string_passam_sem_mudar(self, urlopen):
        urlopen.return_value = resposta(200, b"")
        for url in ("https://exemplo/2020/03%20-%20Mar%C3%A7o/VRA_20203.csv",
                    "https://exemplo/frmDownload.aspx?tema=14"):
            coletar.baixar(url)
            self.assertEqual(urlopen.call_args[0][0].full_url, url)


if __name__ == "__main__":
    unittest.main()
