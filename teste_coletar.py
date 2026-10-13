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


class TesteSituacao(unittest.TestCase):
    def test_traducao_do_status(self):
        self.assertEqual(coletar.situacao(200), "ok")
        self.assertEqual(coletar.situacao(None), "falha_rede")
        self.assertEqual(coletar.situacao(404), "erro_404")
        self.assertEqual(coletar.situacao(403), "erro_403")
        for status in (500, 502, 503, 504):
            self.assertEqual(coletar.situacao(status), "erro_5xx")
        self.assertEqual(coletar.situacao(400), "erro_400")


@patch("coletar.time.sleep", return_value=None)
@patch("coletar.baixar")
class TesteReentrega(unittest.TestCase):
    def test_5xx_reentrega_e_desiste(self, baixar, sleep):
        baixar.return_value = (500, b"")
        self.assertEqual(coletar.buscar("https://exemplo/x.csv"), ("erro_5xx", b""))
        self.assertEqual(baixar.call_count, coletar.TENTATIVAS)

    def test_5xx_depois_sucesso(self, baixar, sleep):
        baixar.side_effect = [(503, b""), (200, b"dados")]
        self.assertEqual(coletar.buscar("https://exemplo/x.csv"), ("ok", b"dados"))

    def test_falha_de_rede_tambem_reentrega(self, baixar, sleep):
        # erro do servidor e falha de rede saem separados, mas as duas reentregam
        baixar.return_value = (None, b"")
        self.assertEqual(coletar.buscar("https://exemplo/x.csv"), ("falha_rede", b""))
        self.assertEqual(baixar.call_count, coletar.TENTATIVAS)

    def test_falha_de_rede_depois_sucesso(self, baixar, sleep):
        baixar.side_effect = [(None, b""), (None, b""), (200, b"dados")]
        self.assertEqual(coletar.buscar("https://exemplo/x.csv"), ("ok", b"dados"))

    def test_espera_cresce_a_cada_tentativa(self, baixar, sleep):
        baixar.return_value = (None, b"")
        coletar.buscar("https://exemplo/x.csv")
        esperas = [chamada[0][0] for chamada in sleep.call_args_list]
        self.assertEqual(esperas, [coletar.ESPERA_BASE, 2 * coletar.ESPERA_BASE])

    def test_404_desiste_na_hora(self, baixar, sleep):
        # mes que ainda nao saiu: tentar de novo so atrasa a coleta
        baixar.return_value = (404, b"")
        self.assertEqual(coletar.buscar("https://exemplo/x.csv"), ("erro_404", b""))
        self.assertEqual(baixar.call_count, 1)
        sleep.assert_not_called()

    def test_403_desiste_na_hora(self, baixar, sleep):
        baixar.return_value = (403, b"")
        self.assertEqual(coletar.buscar("https://exemplo/x.csv"), ("erro_403", b""))
        self.assertEqual(baixar.call_count, 1)

    def test_outro_status_desiste_na_hora(self, baixar, sleep):
        baixar.return_value = (400, b"")
        self.assertEqual(coletar.buscar("https://exemplo/x.csv"), ("erro_400", b""))
        self.assertEqual(baixar.call_count, 1)


class TesteMesesEUrls(unittest.TestCase):
    def test_virada_de_ano(self):
        self.assertEqual(coletar.gerar_meses(202411, 202502), [202411, 202412, 202501, 202502])

    def test_mesmo_mes(self):
        self.assertEqual(coletar.gerar_meses(202401, 202401), [202401])

    def test_fim_padrao_e_o_mes_corrente(self):
        meses = coletar.gerar_meses(201901)
        hoje = coletar.date.today()
        self.assertEqual(meses[0], 201901)
        self.assertEqual(meses[-1], hoje.year * 100 + hoje.month)

    def test_urls_das_tarifas_na_virada_de_ano(self):
        urls = [coletar.montar_url("tarifas", m) for m in coletar.gerar_meses(202411, 202502)]
        base = "https://sas.anac.gov.br/sas/tarifadomestica/"
        self.assertEqual(urls, [
            base + "2024/202411.csv",
            base + "2024/202412.csv",
            base + "2025/202501.csv",
            base + "2025/202502.csv",
        ])

    def test_urls_do_vra_na_virada_de_ano(self):
        # pasta com o mes com zero e por extenso; arquivo com o mes sem zero
        urls = [coletar.montar_url("vra", m) for m in coletar.gerar_meses(202411, 202502)]
        sufixos = [u[len(coletar.VRA):] for u in urls]
        self.assertEqual(sufixos, [
            "/2024/11 - Novembro/VRA_202411.csv",
            "/2024/12 - Dezembro/VRA_202412.csv",
            "/2025/01 - Janeiro/VRA_20251.csv",
            "/2025/02 - Fevereiro/VRA_20252.csv",
        ])

    def test_vra_de_marco_leva_o_cedilha(self):
        self.assertTrue(coletar.montar_url("vra", 202003).endswith("/2020/03 - Março/VRA_20203.csv"))


if __name__ == "__main__":
    unittest.main()
