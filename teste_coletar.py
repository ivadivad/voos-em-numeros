"""Testes do coletor. So biblioteca padrao, sem tocar na rede.

Uso: python teste_coletar.py
"""
import hashlib
import http.client
import io
import os
import shutil
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch
from urllib.error import HTTPError, URLError

import coletar

FIXTURES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures")


def fixture(nome):
    """Bytes de uma pagina da ANAC salva em fixtures/, exatamente como veio."""
    with open(os.path.join(FIXTURES, nome), "rb") as arquivo:
        return arquivo.read()


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


class TesteLeituraDePaginas(unittest.TestCase):
    """Paginas da ANAC salvas em 13/10/2026: nenhum teste aqui usa rede."""

    def test_grade_do_datasas_traz_o_mes_de_cada_arquivo(self):
        arquivos = coletar.arquivos_do_datasas(fixture("datasas_tarifas_2026.html").decode("utf-8"))
        self.assertEqual([m for m, _ in arquivos], list(range(202601, 202609)))
        # o mes vem da tabela; pelo nome, mai/2026 nao seria achado
        self.assertIn((202605, "202605 (1).CSV"), arquivos)

    def test_formulario_do_datasas_tem_os_campos_ocultos(self):
        ocultos = coletar.ler_html(fixture("datasas_formulario.html").decode("utf-8")).ocultos
        self.assertIn("__VIEWSTATE", ocultos)
        self.assertTrue(ocultos["__VIEWSTATE"])

    def test_formulario_sem_busca_nao_tem_arquivos(self):
        self.assertEqual(coletar.arquivos_do_datasas(fixture("datasas_formulario.html").decode("utf-8")), [])

    def test_pasta_do_mes_do_vra(self):
        nomes = coletar.arquivos_da_pasta(fixture("vra_pasta_2026_08.html").decode("utf-8"))
        self.assertEqual(nomes, ["VRA_20268.csv", "VRA_20268.json"])

    def test_pasta_do_ano_so_tem_subpastas(self):
        # subpastas e a pasta de cima ("../") nao sao arquivos
        self.assertEqual(coletar.arquivos_da_pasta(fixture("vra_pasta_2026.html").decode("utf-8")), [])


class TesteAcharNaListagem(unittest.TestCase):
    def setUp(self):
        coletar._listas_datasas.clear()

    def tearDown(self):
        coletar._listas_datasas.clear()

    @patch("coletar.buscar")
    def test_tarifas_acha_o_mes_com_outro_nome(self, buscar):
        # GET do formulario e POST com o ano, nessa ordem
        buscar.side_effect = [("ok", fixture("datasas_formulario.html")),
                              ("ok", fixture("datasas_tarifas_2026.html"))]
        situacao, url = coletar.achar_na_listagem("tarifas", 202605)
        self.assertEqual((situacao, url), ("ok", "https://sas.anac.gov.br/sas/tarifadomestica/2026/202605 (1).CSV"))
        post = buscar.call_args_list[1]
        self.assertIn(b"listAno=2026", post.kwargs["dados"])
        self.assertIn(b"__VIEWSTATE=", post.kwargs["dados"])

    @patch("coletar.buscar")
    def test_mes_fora_da_lista_nao_tem_url(self, buscar):
        buscar.side_effect = [("ok", fixture("datasas_formulario.html")),
                              ("ok", fixture("datasas_tarifas_2026.html"))]
        self.assertEqual(coletar.achar_na_listagem("tarifas", 202609), ("ok", None))

    @patch("coletar.buscar")
    def test_lista_do_ano_e_consultada_uma_vez_so(self, buscar):
        buscar.side_effect = [("ok", fixture("datasas_formulario.html")),
                              ("ok", fixture("datasas_tarifas_2026.html"))]
        coletar.achar_na_listagem("tarifas", 202609)
        coletar.achar_na_listagem("tarifas", 202610)
        self.assertEqual(buscar.call_count, 2)

    @patch("coletar.buscar")
    def test_datasas_fora_do_ar_devolve_a_falha(self, buscar):
        buscar.return_value = ("erro_5xx", b"")
        self.assertEqual(coletar.achar_na_listagem("tarifas", 202605), ("erro_5xx", None))

    @patch("coletar.buscar")
    def test_falha_da_listagem_nao_fica_guardada(self, buscar):
        # o proximo mes que precisa da lista tenta de novo, e acha
        buscar.side_effect = [("erro_5xx", b""),
                              ("ok", fixture("datasas_formulario.html")),
                              ("ok", fixture("datasas_tarifas_2026.html"))]
        self.assertEqual(coletar.achar_na_listagem("tarifas", 202605), ("erro_5xx", None))
        self.assertEqual(coletar.achar_na_listagem("tarifas", 202605)[0], "ok")
        self.assertEqual(buscar.call_count, 3)

    @patch("coletar.buscar")
    def test_vra_acha_o_csv_na_pasta_do_mes(self, buscar):
        buscar.return_value = ("ok", fixture("vra_pasta_2026_08.html"))
        situacao, url = coletar.achar_na_listagem("vra", 202608)
        self.assertEqual((situacao, url), ("ok", coletar.VRA + "/2026/08 - Agosto/VRA_20268.csv"))
        self.assertEqual(buscar.call_args[0][0], coletar.VRA + "/2026/08 - Agosto/")

    @patch("coletar.buscar")
    def test_vra_pasta_vazia_nao_tem_url(self, buscar):
        buscar.return_value = ("ok", b"<html><body><pre><a href=\"../\">../</a></pre></body></html>")
        self.assertEqual(coletar.achar_na_listagem("vra", 202609), ("ok", None))

    @patch("coletar.buscar")
    def test_vra_pasta_que_nao_existe_e_404(self, buscar):
        # a pasta do mes so aparece quando o mes sai
        buscar.return_value = ("erro_404", b"")
        self.assertEqual(coletar.achar_na_listagem("vra", 202610), ("erro_404", None))


class TesteBaixarMes(unittest.TestCase):
    @patch("coletar.achar_na_listagem")
    @patch("coletar.buscar")
    def test_padrao_que_funciona_nao_consulta_a_listagem(self, buscar, achar):
        buscar.return_value = ("ok", b"dados")
        self.assertEqual(coletar.baixar_mes("tarifas", 202604)[:2], ("ok", b"dados"))
        achar.assert_not_called()

    @patch("coletar.achar_na_listagem")
    @patch("coletar.buscar")
    def test_404_no_padrao_baixa_o_que_a_listagem_achou(self, buscar, achar):
        url = "https://sas.anac.gov.br/sas/tarifadomestica/2026/202605 (1).CSV"
        achar.return_value = ("ok", url)
        buscar.side_effect = [("erro_404", b""), ("ok", b"dados")]
        self.assertEqual(coletar.baixar_mes("tarifas", 202605), ("ok", b"dados", url))

    @patch("coletar.achar_na_listagem")
    @patch("coletar.buscar")
    def test_404_sem_nada_na_listagem_continua_404(self, buscar, achar):
        achar.return_value = ("ok", None)
        buscar.return_value = ("erro_404", b"")
        situacao, _, url = coletar.baixar_mes("tarifas", 202609)
        self.assertEqual(situacao, "erro_404")
        self.assertTrue(url.endswith("/2026/202609.csv"))

    @patch("coletar.achar_na_listagem")
    @patch("coletar.buscar")
    def test_listagem_com_404_continua_404(self, buscar, achar):
        achar.return_value = ("erro_404", None)
        buscar.return_value = ("erro_404", b"")
        self.assertEqual(coletar.baixar_mes("vra", 202610)[0], "erro_404")

    @patch("coletar.achar_na_listagem")
    @patch("coletar.buscar")
    def test_listagem_fora_do_ar_nao_vira_404(self, buscar, achar):
        # sem a listagem, nao da pra dizer que o mes nao saiu: a situacao e a
        # da falha, e a coleta sai com erro em vez de dar o mes por nao publicado
        buscar.return_value = ("erro_404", b"")
        for falha in ("erro_5xx", "falha_rede", "erro_403"):
            with self.subTest(falha=falha):
                achar.return_value = (falha, None)
                self.assertEqual(coletar.baixar_mes("tarifas", 202609)[0], falha)

    @patch("coletar.achar_na_listagem")
    @patch("coletar.buscar")
    def test_falha_de_rede_nao_consulta_a_listagem(self, buscar, achar):
        # so 404 quer dizer "nao esta nesse endereco"; falha de rede, nao
        buscar.return_value = ("falha_rede", b"")
        self.assertEqual(coletar.baixar_mes("vra", 202608)[0], "falha_rede")
        achar.assert_not_called()


TARIFA = b"nr_ano_referencia;nr_mes_referencia\r\n2026;5\r\n"


class ComPastaTemporaria(unittest.TestCase):
    """Cada teste grava numa pasta temporaria, apagada no fim."""

    def setUp(self):
        self.pasta = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.pasta)

    def bruto(self, base, nome):
        return coletar.caminho_bruto(base, nome, self.pasta)


class TesteGravacaoDoBruto(ComPastaTemporaria):
    def test_grava_os_bytes_como_vieram(self):
        caminho = self.bruto("tarifas", "202605.csv")
        coletar.gravar_bruto(TARIFA, caminho)
        with open(caminho, "rb") as arquivo:
            self.assertEqual(arquivo.read(), TARIFA)  # o \r\n da ANAC fica
        self.assertFalse(os.path.exists(caminho + ".parcial"))

    def test_regravar_troca_o_arquivo_inteiro(self):
        caminho = self.bruto("tarifas", "202605.csv")
        coletar.gravar_bruto(b"versao antiga e mais longa\n", caminho)
        coletar.gravar_bruto(b"nova\n", caminho)
        with open(caminho, "rb") as arquivo:
            self.assertEqual(arquivo.read(), b"nova\n")

    def test_vazio_conta_as_linhas_de_cabecalho_da_base(self):
        self.assertTrue(coletar.vazio(b"", 1))
        self.assertTrue(coletar.vazio(b"ANO;MES\r\n", 1))
        self.assertFalse(coletar.vazio(b"ANO;MES\r\n2026;5\r\n", 1))
        # VRA: "Atualizado em" e o cabecalho nao sao dado
        self.assertTrue(coletar.vazio(b"Atualizado em: 2026-10-07\r\n\"ICAO\";\"Voo\"\r\n", 2))

    def test_alvos_da_base_mensal_tem_nome_local_aaaamm(self):
        self.assertEqual(coletar.alvos("vra", 202512, 202601),
                         [("202512", "202512.csv"), ("202601", "202601.csv")])

    def test_alvos_da_base_fixa_sao_os_arquivos_do_fontes(self):
        self.assertEqual(coletar.alvos("aerodromos"),
                         [("", "AerodromosPublicos.csv"), ("", "AerodromosPrivados.csv")])


@patch("coletar.time.sleep", return_value=None)
class TesteColetarBase(ComPastaTemporaria):
    @patch("coletar.baixar_mes")
    def test_mes_que_falta_e_baixado_com_nome_local(self, baixar_mes, sleep):
        baixar_mes.return_value = ("ok", TARIFA, "https://x/2026/202605 (1).CSV")
        [registro] = coletar.coletar_base("tarifas", 202605, 202605, pasta=self.pasta)
        self.assertTrue(os.path.exists(self.bruto("tarifas", "202605.csv")))
        self.assertEqual(registro["situacao"], "ok")
        self.assertTrue(registro["baixado"])
        self.assertEqual(registro["bytes"], len(TARIFA))
        self.assertEqual(registro["sha256"], hashlib.sha256(TARIFA).hexdigest())
        self.assertEqual(registro["url"], "https://x/2026/202605 (1).CSV")

    @patch("coletar.baixar_mes")
    def test_mes_ja_baixado_e_pulado_sem_rede(self, baixar_mes, sleep):
        coletar.gravar_bruto(TARIFA, self.bruto("tarifas", "202605.csv"))
        [registro] = coletar.coletar_base("tarifas", 202605, 202605, pasta=self.pasta)
        baixar_mes.assert_not_called()
        self.assertEqual((registro["situacao"], registro["baixado"]), ("ok", False))

    @patch("coletar.baixar_mes")
    def test_revisar_baixa_de_novo_o_que_ja_existe(self, baixar_mes, sleep):
        coletar.gravar_bruto(b"versao antiga\n", self.bruto("tarifas", "202605.csv"))
        baixar_mes.return_value = ("ok", TARIFA, "https://x")
        coletar.coletar_base("tarifas", 202605, 202605, pasta=self.pasta, revisar=True)
        with open(self.bruto("tarifas", "202605.csv"), "rb") as arquivo:
            self.assertEqual(arquivo.read(), TARIFA)

    @patch("coletar.baixar_mes")
    def test_404_e_arquivo_vazio_nao_sao_gravados(self, baixar_mes, sleep):
        baixar_mes.side_effect = [("erro_404", b"", "https://x/a"), ("ok", b"ANO;MES\r\n", "https://x/b")]
        registros = coletar.coletar_base("tarifas", 202609, 202610, pasta=self.pasta)
        self.assertEqual([r["situacao"] for r in registros], ["erro_404", "vazio"])
        self.assertFalse(os.path.exists(os.path.join(self.pasta, "brutos")))

    @patch("coletar.buscar")
    def test_arquivo_fixo_e_sempre_baixado_de_novo(self, buscar, sleep):
        buscar.return_value = ("ok", b"Atualizado em: hoje\r\nCodigo\r\nSBSP\r\n")
        coletar.gravar_bruto(b"retrato antigo\n", self.bruto("aerodromos", "AerodromosPublicos.csv"))
        registros = coletar.coletar_base("aerodromos", pasta=self.pasta)
        self.assertEqual(buscar.call_count, 2)
        self.assertTrue(all(r["baixado"] for r in registros))


class TesteManifesto(ComPastaTemporaria):
    def registro(self, sha, arquivo="202605.csv", baixado=True):
        return {"base": "tarifas", "periodo": "202605", "arquivo": arquivo, "url": "https://x",
                "baixado": baixado, "bytes": 10, "sha256": sha}

    def manifesto(self):
        return coletar.ler_csv(os.path.join(self.pasta, coletar.MANIFESTO))

    def test_arquivo_baixado_entra_no_manifesto(self):
        novas, revisados = coletar.atualizar_manifesto([self.registro("a" * 64)], self.pasta, hoje="2026-10-13")
        self.assertEqual(len(novas), 1)
        self.assertEqual(revisados, [])
        [linha] = self.manifesto()
        self.assertEqual((linha["sha256"], linha["coletado_em"], linha["bytes"]), ("a" * 64, "2026-10-13", "10"))

    def test_mesmo_sha_nao_duplica_nem_regrava(self):
        coletar.atualizar_manifesto([self.registro("a" * 64)], self.pasta, hoje="2026-10-13")
        caminho = os.path.join(self.pasta, coletar.MANIFESTO)
        antes = os.path.getmtime(caminho)
        os.utime(caminho, (antes - 100, antes - 100))
        novas, _ = coletar.atualizar_manifesto([self.registro("a" * 64)], self.pasta, hoje="2026-11-13")
        self.assertEqual(novas, [])
        self.assertEqual(len(self.manifesto()), 1)
        self.assertEqual(os.path.getmtime(caminho), antes - 100)  # nem foi aberto pra escrita

    def test_sha_novo_e_revisao_e_as_duas_versoes_ficam(self):
        coletar.atualizar_manifesto([self.registro("a" * 64)], self.pasta, hoje="2026-07-01")
        novas, revisados = coletar.atualizar_manifesto([self.registro("b" * 64)], self.pasta, hoje="2026-10-13")
        self.assertEqual(revisados, [("tarifas", "202605.csv")])
        self.assertEqual([(l["sha256"][0], l["coletado_em"]) for l in self.manifesto()],
                         [("a", "2026-07-01"), ("b", "2026-10-13")])

    def test_arquivo_pulado_nao_entra(self):
        novas, _ = coletar.atualizar_manifesto([self.registro(None, baixado=False)], self.pasta)
        self.assertEqual(novas, [])
        self.assertFalse(os.path.exists(os.path.join(self.pasta, coletar.MANIFESTO)))

    def test_manifesto_sai_ordenado_e_com_lf(self):
        # gravar duas vezes o mesmo conteudo tem que dar o mesmo arquivo
        registros = [self.registro("b" * 64, "202606.csv"), self.registro("a" * 64, "202605.csv")]
        coletar.atualizar_manifesto(registros, self.pasta, hoje="2026-10-13")
        with open(os.path.join(self.pasta, coletar.MANIFESTO), "rb") as arquivo:
            conteudo = arquivo.read()
        self.assertNotIn(b"\r\n", conteudo)
        self.assertEqual([l["arquivo"] for l in self.manifesto()], ["202605.csv", "202606.csv"])

    def test_ler_csv_ausente(self):
        self.assertEqual(coletar.ler_csv(os.path.join(self.pasta, "nao-existe.csv")), [])


def reg(base, periodo, situacao, arquivo=None):
    return {"base": base, "periodo": periodo, "arquivo": arquivo or f"{periodo}.csv", "situacao": situacao,
            "url": "", "baixado": False}


class TesteCobertura(ComPastaTemporaria):
    def cobertura(self):
        return [(l["base"], l["periodo"], l["situacao"])
                for l in coletar.ler_csv(os.path.join(self.pasta, coletar.COBERTURA))]

    def test_uma_linha_por_arquivo_ordenada(self):
        coletar.gravar_cobertura([reg("vra", "202609", "erro_404"), reg("tarifas", "202608", "ok"),
                                  reg("aerodromos", "", "falha_rede", "AerodromosPublicos.csv")], self.pasta)
        self.assertEqual(self.cobertura(), [("aerodromos", "", "falha_rede"), ("tarifas", "202608", "ok"),
                                            ("vra", "202609", "erro_404")])

    def test_coleta_parcial_mantem_o_resto(self):
        coletar.gravar_cobertura([reg("tarifas", "202607", "ok"), reg("tarifas", "202608", "falha_rede"),
                                  reg("vra", "202608", "ok")], self.pasta)
        coletar.gravar_cobertura([reg("tarifas", "202608", "ok")], self.pasta)
        self.assertEqual(self.cobertura(), [("tarifas", "202607", "ok"), ("tarifas", "202608", "ok"),
                                            ("vra", "202608", "ok")])

    def test_mesma_coleta_da_o_mesmo_arquivo(self):
        registros = [reg("tarifas", "202608", "ok"), reg("tarifas", "202609", "erro_404")]
        caminho = os.path.join(self.pasta, coletar.COBERTURA)
        coletar.gravar_cobertura(registros, self.pasta)
        with open(caminho, "rb") as arquivo:
            primeira = arquivo.read()
        coletar.gravar_cobertura(registros, self.pasta)
        with open(caminho, "rb") as arquivo:
            self.assertEqual(arquivo.read(), primeira)
        self.assertNotIn(b"\r\n", primeira)


class TesteErros(unittest.TestCase):
    def test_404_depois_do_ultimo_mes_e_mes_que_nao_saiu(self):
        self.assertEqual(coletar.erros([reg("tarifas", "202608", "ok"), reg("tarifas", "202609", "erro_404")]), [])

    def test_404_no_meio_da_serie_e_erro(self):
        buraco = reg("tarifas", "202605", "erro_404")
        self.assertEqual(coletar.erros([reg("tarifas", "202604", "ok"), buraco, reg("tarifas", "202606", "ok")]),
                         [buraco])

    def test_nenhum_mes_veio_entao_404_e_erro(self):
        # no MED, uma rodada sem nada ok terminava verde
        tudo_404 = [reg("vra", "202608", "erro_404"), reg("vra", "202609", "erro_404")]
        self.assertEqual(coletar.erros(tudo_404), tudo_404)

    def test_404_de_arquivo_fixo_e_erro(self):
        sumiu = reg("estatisticas", "", "erro_404", "Dados_Estatisticos.csv")
        self.assertEqual(coletar.erros([sumiu]), [sumiu])

    def test_403_5xx_e_falha_de_rede_sao_erro(self):
        ruins = [reg("tarifas", "202606", "erro_403"), reg("tarifas", "202607", "erro_5xx"),
                 reg("tarifas", "202608", "falha_rede")]
        self.assertEqual(coletar.erros([reg("tarifas", "202605", "ok")] + ruins), ruins)

    def test_ultimo_mes_e_por_base(self):
        # o vra ter ago/2026 nao faz o 404 de ago/2026 das tarifas virar buraco
        registros = [reg("vra", "202608", "ok"), reg("tarifas", "202607", "ok"), reg("tarifas", "202608", "erro_404")]
        self.assertEqual(coletar.erros(registros), [])


class TesteMain(ComPastaTemporaria):
    """main() grava em dados/ relativo a pasta atual: roda dentro da temporaria."""

    def setUp(self):
        super().setUp()
        self.original = os.getcwd()
        os.chdir(self.pasta)
        self.saida = patch("sys.stdout", new_callable=io.StringIO)
        self.saida.start()

    def tearDown(self):
        self.saida.stop()
        os.chdir(self.original)
        super().tearDown()

    @patch("coletar.coletar_base")
    def test_rodada_ok_grava_e_sai_sem_erro(self, coletar_base):
        coletar_base.return_value = [reg("tarifas", "202608", "ok"), reg("tarifas", "202609", "erro_404")]
        self.assertEqual(coletar.main(["tarifas", "--desde", "202608"]), 0)
        self.assertTrue(os.path.exists(os.path.join("dados", "cobertura.csv")))
        self.assertEqual(coletar_base.call_args[0], ("tarifas", 202608, None))

    @patch("coletar.coletar_base")
    def test_buraco_na_serie_sai_com_erro(self, coletar_base):
        coletar_base.return_value = [reg("tarifas", "202604", "ok"), reg("tarifas", "202605", "erro_404"),
                                     reg("tarifas", "202606", "ok")]
        self.assertEqual(coletar.main(["tarifas"]), 1)

    @patch("coletar.coletar_base")
    def test_rodada_sem_nada_ok_nao_grava_e_sai_com_erro(self, coletar_base):
        coletar_base.return_value = [reg("vra", "202608", "falha_rede")]
        self.assertEqual(coletar.main(["vra"]), 1)
        self.assertFalse(os.path.exists("dados"))

    @patch("coletar.coletar_base")
    def test_todas_passa_pelas_quatro_bases(self, coletar_base):
        coletar_base.side_effect = lambda base, *a, **k: [reg(base, "202608", "ok")]
        self.assertEqual(coletar.main(["todas"]), 0)
        self.assertEqual([c[0][0] for c in coletar_base.call_args_list],
                         ["aerodromos", "estatisticas", "tarifas", "vra"])

    @patch("coletar.coletar_base")
    def test_revisar_chega_na_coleta(self, coletar_base):
        coletar_base.return_value = [reg("tarifas", "202608", "ok")]
        coletar.main(["tarifas", "--revisar"])
        self.assertTrue(coletar_base.call_args.kwargs["revisar"])

    @patch("coletar.coletar_base")
    def test_listar_nao_coleta(self, coletar_base):
        self.assertEqual(coletar.main(["--listar"]), 0)
        coletar_base.assert_not_called()
        self.assertIn("tarifas", sys.stdout.getvalue())


if __name__ == "__main__":
    unittest.main()
