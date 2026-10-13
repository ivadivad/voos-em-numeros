"""Testes do coletor. So biblioteca padrao, sem tocar na rede.

Uso: python teste_coletar.py
"""
import unittest

import coletar


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


if __name__ == "__main__":
    unittest.main()
