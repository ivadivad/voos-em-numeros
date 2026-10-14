"""Constroi o banco do projeto rodando os .sql em ordem.

Toda transformacao mora em sql/, em arquivos .sql versionados e legiveis no
GitHub; aqui o Python so orquestra. Cada rodada parte de um banco vazio:
apaga o voos.duckdb e roda sql/*.sql em ordem alfabetica (o prefixo numerico
da a ordem: 00_brutos, 10_stg_..., 20_dim_...), mostrando o tempo de cada
arquivo e parando no primeiro erro. Depois roda os testes de sql/testes/:
cada teste e uma consulta que devolve zero linhas quando esta tudo certo.

Uso: python construir.py   (da raiz do repositorio, depois do coletar.py)

Sai com codigo 1 quando um .sql falha ou um teste devolve linhas, pra
construcao quebrada ficar visivel.
"""
import argparse
import glob
import os
import sys
import textwrap
import time

import duckdb

PASTA_SQL = "sql"
BANCO = "voos.duckdb"  # fora do git (.gitignore)
PASTA_BRUTOS = os.path.join("dados", "brutos")  # de onde os .sql leem os arquivos da ANAC
LINHAS_MOSTRADAS = 5  # de cada teste que falha


def arquivos_sql(pasta=PASTA_SQL):
    """Os .sql de `pasta`, em ordem alfabetica. So os da propria pasta: os
    testes, em sql/testes/, nao sao modelos."""
    return sorted(glob.glob(os.path.join(pasta, "*.sql")))


def apagar_banco(banco):
    """Apaga o banco e o WAL dele. Construir do zero impede que um objeto
    que saiu dos .sql continue no banco e a construcao so funcione na
    maquina de quem rodou antes."""
    for caminho in (banco, banco + ".wal"):
        if os.path.exists(caminho):
            os.remove(caminho)


def rodar(con, arquivos):
    """Roda cada arquivo, em ordem, e mostra o tempo de cada um. Para no
    primeiro erro e devolve o arquivo que falhou, ou None.

    Um arquivo pode ter varios comandos. Erro de sintaxe impede o arquivo
    inteiro; erro no meio deixa feito o que veio antes dele, e o banco fica
    como estava no erro, pra ser aberto e investigado.
    """
    for caminho in arquivos:
        with open(caminho, encoding="utf-8") as arquivo:
            sql = arquivo.read()
        print(f"{os.path.basename(caminho):32}", end="", flush=True)
        inicio = time.perf_counter()
        try:
            con.execute(sql)
        except duckdb.Error as erro:
            print("ERRO")
            print(textwrap.indent(str(erro), "  "))
            return caminho
        print(f"{time.perf_counter() - inicio:7.1f}s")
    return None


def testar(con, arquivos):
    """Roda cada teste e devolve a lista dos que falharam.

    Teste que devolve linhas falhou: mostra quantas e as primeiras, que
    sao a pista do problema. Ao contrario dos modelos, nao para no primeiro:
    roda todos, pra uma rodada mostrar tudo que esta errado.
    """
    falharam = []
    for caminho in arquivos:
        with open(caminho, encoding="utf-8") as arquivo:
            sql = arquivo.read()
        print(f"{'testes/' + os.path.basename(caminho):48}", end="", flush=True)
        inicio = time.perf_counter()
        try:
            consulta = con.sql(sql)
            primeiras = consulta.limit(LINHAS_MOSTRADAS).fetchall()
            total = consulta.count("*").fetchone()[0] if primeiras else 0
        except duckdb.Error as erro:
            print("ERRO")
            print(textwrap.indent(str(erro), "  "))
            falharam.append(caminho)
            continue
        if not primeiras:
            print(f"{time.perf_counter() - inicio:7.1f}s")
            continue
        print(f"FALHOU: {total} linha(s)")
        for linha in [consulta.columns] + primeiras:
            print("  " + " | ".join(str(valor) for valor in linha))
        falharam.append(caminho)
    return falharam


def construir(pasta_sql=PASTA_SQL, banco=BANCO):
    """Apaga o banco, roda os .sql e depois os testes. Devolve o codigo de
    saida: 0 se tudo rodou e passou; 1 se um arquivo falhou, se um teste
    falhou ou se nao havia nada pra rodar (no MED, rodada vazia que
    terminava verde escondeu problema)."""
    arquivos = arquivos_sql(pasta_sql)
    if not arquivos:
        print(f"nenhum .sql em {pasta_sql}/")
        return 1
    try:
        apagar_banco(banco)
    except PermissionError:
        print(f"{banco} esta aberto em outro programa; feche e rode de novo")
        return 1
    inicio = time.perf_counter()
    testes = arquivos_sql(os.path.join(pasta_sql, "testes"))
    with duckdb.connect(banco) as con:
        if rodar(con, arquivos):
            return 1
        falharam = testar(con, testes)
    if falharam:
        # o banco fica como esta, pra abrir e investigar as linhas
        print(f"{len(falharam)} de {len(testes)} testes falharam: {banco}")
        return 1
    print(f"pronto em {time.perf_counter() - inicio:.0f}s, {len(testes)} testes passaram: {banco}")
    return 0


def main(argv):
    # sem opcoes por enquanto; o argparse fica pelo --help, que sem ele
    # apagaria o banco e construiria tudo de novo
    argparse.ArgumentParser(description="Constroi o voos.duckdb a partir dos brutos da ANAC").parse_args(argv)
    if not os.path.isdir(PASTA_BRUTOS):
        print(f"{PASTA_BRUTOS} nao existe: rode python coletar.py todas antes")
        return 1
    return construir()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
