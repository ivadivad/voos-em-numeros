"""Coletor das bases da ANAC usadas no projeto.

Baixa os arquivos como a ANAC publica, sem mexer no conteudo, para
dados/brutos/<base>/. O que cada base e, linha a linha, esta no
DICIONARIO.md; aqui fica so onde buscar cada arquivo e como ele chega.

So biblioteca padrao: roda em qualquer Python 3, sem pip install.

Uso: python coletar.py <base|todas> [--desde AAAAMM] [--ate AAAAMM] [--revisar]
     python coletar.py --listar

Sai com codigo 1 quando alguma coisa falhou (403, 5xx, falha de rede, ou
404 no meio da serie), pra coleta com erro ficar visivel. 404 depois do
ultimo mes publicado e mes que ainda nao saiu, e nao conta.
"""
import argparse
import csv
import hashlib
import http.client
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from datetime import date
from html.parser import HTMLParser

# o gov.br devolve 403 pro User-Agent padrao do urllib (Python-urllib/3.x);
# com um que identifica o projeto, devolve a pagina
USER_AGENT = "voos-em-numeros/0.1 (+https://github.com/ivadivad/voos-em-numeros)"

VRA = "https://sistemas.anac.gov.br/dadosabertos/Voos e operações aéreas/Voo Regular Ativo (VRA)"
DADOS_ABERTOS = "https://sistemas.anac.gov.br/dadosabertos"

# por base: o tipo ("mensal" = um arquivo por mes; "fixo" = arquivos sem
# mes, sempre na versao mais recente), onde buscar e como o arquivo chega.
# separador, encoding e linhas_cabecalho sao os conferidos na etapa 1.
FONTES = {
    "tarifas": {
        "tipo": "mensal",
        "url": "https://sas.anac.gov.br/sas/tarifadomestica/{ano}/{ano}{mes:02d}.csv",
        # formulario do DataSAS com a lista oficial de arquivos de cada ano:
        # mai/2026 so existe la, como "202605 (1).CSV", baixado de `pasta`
        "listagem": "https://sas.anac.gov.br/sas/downloads/view/frmDownload.aspx?tema=14",
        "pasta": "https://sas.anac.gov.br/sas/tarifadomestica/{ano}/",
        "desde": 201901,
        "separador": ";",
        "encoding": "latin-1",  # dados so em ASCII; acento so em alguns cabecalhos
        "linhas_cabecalho": 1,
    },
    "vra": {
        "tipo": "mensal",
        # pasta com o nome do mes por extenso; arquivo com o mes sem zero
        "url": VRA + "/{ano}/{mes:02d} - {nome_mes}/VRA_{ano}{mes}.csv",
        "listagem": VRA + "/{ano}/{mes:02d} - {nome_mes}/",
        "desde": 201901,
        "separador": ";",
        "encoding": "utf-8-sig",
        "linhas_cabecalho": 2,  # "Atualizado em: ..." e so depois o cabecalho
    },
    "estatisticas": {
        "tipo": "fixo",
        # o acumulado de 2000 ate hoje, no lugar dos zips mensais (etapa 1)
        "arquivos": {
            "Dados_Estatisticos.csv": DADOS_ABERTOS
            + "/Voos e operações aéreas/Dados Estatísticos do Transporte Aéreo/Dados_Estatisticos.csv",
        },
        "separador": ";",
        "encoding": "utf-8-sig",
        "linhas_cabecalho": 2,
    },
    "aerodromos": {
        "tipo": "fixo",
        # a lista de privados entra porque tarifas e VRA tem aeroportos dela
        "arquivos": {
            "AerodromosPublicos.csv": DADOS_ABERTOS
            + "/Aerodromos/Aeródromos Públicos/Lista de aeródromos públicos/AerodromosPublicos.csv",
            "AerodromosPrivados.csv": DADOS_ABERTOS
            + "/Aerodromos/Aeródromos Privados/Lista de aeródromos privados/Aerodromos Privados/AerodromosPrivados.csv",
        },
        "separador": ";",
        "encoding": "latin-1",
        "linhas_cabecalho": 2,
    },
}

TENTATIVAS = 3
ESPERA_BASE = 2  # segundos; cresce a cada nova tentativa
PAUSA = 1  # segundos entre um download e outro: em rajada, o servidor derruba conexoes

PASTA_DADOS = "dados"
MANIFESTO = "manifesto.csv"  # em dados/, versionado; os brutos, nao
COLUNAS_MANIFESTO = ["base", "periodo", "arquivo", "bytes", "sha256", "coletado_em", "url"]
COBERTURA = "cobertura.csv"  # em dados/, versionado
COLUNAS_COBERTURA = ["base", "periodo", "arquivo", "situacao"]

# nomes das pastas mensais do VRA ("03 - Março")
MESES = [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
]


def baixar(url, timeout=120, dados=None, abridor=None):
    """Faz um GET (ou um POST, com `dados`) e devolve (status, bytes). Nunca
    levanta excecao por problema de rede ou do servidor.

    status None quer dizer que nem chegou resposta inteira: timeout,
    conexao recusada ou derrubada no meio do arquivo (o servidor da ANAC
    faz isso). Acento, espaco e parentese viram %XX aqui, entao FONTES
    guarda a URL legivel; uma URL ja codificada passa sem mudar. `abridor`
    serve pra manter cookies entre pedidos (formulario do DataSAS).
    """
    pedido = urllib.request.Request(
        urllib.parse.quote(url, safe=":/?=&%"), data=dados, headers={"User-Agent": USER_AGENT}
    )
    abrir = abridor.open if abridor else urllib.request.urlopen
    try:
        with abrir(pedido, timeout=timeout) as resposta:
            return resposta.status, resposta.read()
    except urllib.error.HTTPError as erro:
        erro.close()  # o erro carrega a resposta aberta; sem fechar, a conexao fica pendurada
        return erro.code, b""
    except (OSError, http.client.HTTPException):
        # HTTPException: IncompleteRead quando a conexao cai no meio do corpo
        return None, b""


def situacao(status):
    """Traduz o status HTTP na situacao registrada na cobertura.

    Separa servidor com erro (erro_5xx) de resposta que nem chegou
    (falha_rede): no MED, juntar os dois levou a um diagnostico errado.
    """
    if status == 200:
        return "ok"
    if status is None:
        return "falha_rede"
    if 500 <= status < 600:
        return "erro_5xx"
    return f"erro_{status}"


def buscar(url, **opcoes):
    """Baixa com reentrega. Devolve (situacao, bytes). `opcoes` vao pro
    baixar() (dados de POST, abridor com cookies).

    Reentrega, com espera crescente, quando o servidor erra (5xx) ou a
    resposta nao chega (falha_rede): as duas costumam passar sozinhas. 404
    e 403 desistem na hora: 404 e mes que ainda nao saiu, 403 e bloqueio,
    e nenhum dos dois melhora tentando de novo.
    """
    for tentativa in range(TENTATIVAS):
        status, corpo = baixar(url, **opcoes)
        resultado = situacao(status)
        if resultado in ("erro_5xx", "falha_rede") and tentativa < TENTATIVAS - 1:
            time.sleep(ESPERA_BASE * (tentativa + 1))
            continue
        return resultado, corpo


def gerar_meses(desde, ate=None):
    """Lista de AAAAMM de `desde` ate `ate`, inclusive, mes a mes.

    `ate` default: mes corrente.
    """
    if ate is None:
        hoje = date.today()
        ate = hoje.year * 100 + hoje.month

    ano, mes = divmod(desde, 100)
    fim_ano, fim_mes = divmod(ate, 100)

    meses = []
    while (ano, mes) <= (fim_ano, fim_mes):
        meses.append(ano * 100 + mes)
        mes += 1
        if mes > 12:
            mes = 1
            ano += 1
    return meses


def montar_url(base, mes, chave="url"):
    """URL de um mes (AAAAMM) pelo padrao da base mensal. `chave` escolhe
    qual padrao do FONTES usar: o do arquivo ou o da listagem."""
    ano, numero = divmod(mes, 100)
    return FONTES[base][chave].format(ano=ano, mes=numero, nome_mes=MESES[numero - 1])


class LeitorHtml(HTMLParser):
    """Junta, de uma pagina, os links (<a href>), as linhas de tabela (o
    texto de cada <td> e <th>) e os campos ocultos de formulario."""

    def __init__(self):
        super().__init__()
        self.links = []  # (href, texto)
        self.linhas = []  # uma lista de textos de celula por <tr>
        self.ocultos = {}  # nome -> valor
        self._href = None  # enquanto o texto de um <a> e lido
        self._texto_link = []
        self._celula = None  # enquanto o texto de um <td>/<th> e lido

    def handle_starttag(self, tag, attrs):
        atributos = dict(attrs)
        if tag == "input" and (atributos.get("type") or "").lower() == "hidden" and atributos.get("name"):
            self.ocultos[atributos["name"]] = atributos.get("value") or ""
        elif tag == "a":
            self._href = atributos.get("href")
            self._texto_link = []
        elif tag == "tr":
            self.linhas.append([])
        elif tag in ("td", "th") and self.linhas:
            self._celula = []

    def handle_data(self, data):
        if self._href is not None:
            self._texto_link.append(data)
        if self._celula is not None:
            self._celula.append(data)

    def handle_endtag(self, tag):
        if tag == "a" and self._href is not None:
            self.links.append((self._href, "".join(self._texto_link).strip()))
            self._href = None
        elif tag in ("td", "th") and self._celula is not None:
            self.linhas[-1].append(" ".join("".join(self._celula).split()))
            self._celula = None


def ler_html(html):
    leitor = LeitorHtml()
    leitor.feed(html)
    leitor.close()
    return leitor


def arquivos_da_pasta(html):
    """Nomes dos arquivos de uma listagem de pasta do servidor (o indice que
    aparece ao abrir a pasta no navegador). Ignora subpastas, a pasta de
    cima e os links de ordenacao."""
    nomes = []
    for href, _ in ler_html(html).links:
        if href and not href.endswith("/") and not href.startswith(("?", "/", "#", "http")):
            nomes.append(urllib.parse.unquote(href))
    return nomes


def arquivos_do_datasas(html):
    """Arquivos que o DataSAS lista depois do "Buscar Arquivos", como
    (AAAAMM, nome).

    A lista e uma tabela: caixa de selecao, nome, data e hora do arquivo,
    ano e mes de referencia, tamanho e empresa. O mes sai da tabela, nao do
    nome do arquivo, que pode ser qualquer um ("202605 (1).CSV").
    """
    arquivos = []
    for celulas in ler_html(html).linhas:
        if (len(celulas) == 7 and celulas[1].lower().endswith(".csv")
                and celulas[3].isdigit() and celulas[4].isdigit()):
            arquivos.append((int(celulas[3]) * 100 + int(celulas[4]), celulas[1]))
    return arquivos


_listas_datasas = {}  # (url, ano) -> arquivos; so as consultas que deram certo


def listar_datasas(url, ano):
    """Lista os arquivos de um ano no DataSAS. Devolve (situacao, arquivos),
    com cada arquivo como (AAAAMM, nome).

    O DataSAS e um formulario ASP.NET: a lista so aparece depois de enviar
    o ano junto com os campos ocultos da pagina (__VIEWSTATE e afins), na
    mesma sessao. A lista que veio fica guardada, e um ano so e consultado
    uma vez por rodada. A falha nao fica: o proximo mes que precisar da
    lista tenta de novo.
    """
    if (url, ano) in _listas_datasas:
        return "ok", _listas_datasas[(url, ano)]
    abridor = urllib.request.build_opener(urllib.request.HTTPCookieProcessor())
    resultado, pagina = buscar(url, abridor=abridor)
    if resultado != "ok":
        return resultado, ()
    campos = ler_html(pagina.decode("utf-8", "replace")).ocultos
    campos.update({
        "ctl00$MainContent$listAno": str(ano),
        "ctl00$MainContent$btnListaArquivos": "Buscar Arquivos",
    })
    dados = urllib.parse.urlencode(campos).encode()
    resultado, resposta = buscar(url, dados=dados, abridor=abridor)
    if resultado != "ok":
        return resultado, ()
    _listas_datasas[(url, ano)] = tuple(arquivos_do_datasas(resposta.decode("utf-8", "replace")))
    return "ok", _listas_datasas[(url, ano)]


def achar_na_listagem(base, mes):
    """Procura o mes na listagem oficial. Devolve (situacao da listagem,
    URL do arquivo ou None).

    Serve pro que o padrao de URL nao acha: mai/2026 das tarifas so existe
    como "202605 (1).CSV". Nas tarifas, a lista do ano vem do DataSAS; no
    VRA, da listagem da pasta do mes, que da 404 enquanto o mes nao saiu.
    """
    ano = mes // 100
    if base == "tarifas":
        resultado, arquivos = listar_datasas(FONTES["tarifas"]["listagem"], ano)
        candidatos = [nome for referencia, nome in arquivos if referencia == mes]
        pasta = FONTES["tarifas"]["pasta"].format(ano=ano)
    else:
        pasta = montar_url(base, mes, chave="listagem")
        resultado, pagina = buscar(pasta)
        nomes = arquivos_da_pasta(pagina.decode("utf-8", "replace")) if resultado == "ok" else []
        candidatos = [n for n in nomes if n.lower().endswith(".csv")]
    return resultado, (pasta + sorted(candidatos)[0] if candidatos else None)


def baixar_mes(base, mes):
    """Baixa o arquivo de um mes. Devolve (situacao, bytes, url usada).

    Tenta o padrao de URL; se der 404, procura o mes na listagem oficial
    antes de concluir que ele nao foi publicado. Se a listagem nao
    responder (5xx, falha de rede, 403), a situacao e a dela, e nao 404: sem
    a listagem, nao da pra dizer que o mes nao saiu, e no MED juntar falhas
    diferentes levou a um diagnostico errado.
    """
    url = montar_url(base, mes)
    resultado, corpo = buscar(url)
    if resultado == "erro_404":
        situacao_listagem, alternativa = achar_na_listagem(base, mes)
        if alternativa:
            url = alternativa
            resultado, corpo = buscar(url)
        elif situacao_listagem not in ("ok", "erro_404"):
            resultado = situacao_listagem
    return resultado, corpo, url


def caminho_bruto(base, nome, pasta=PASTA_DADOS):
    """dados/brutos/<base>/<nome>, fora do git (.gitignore)."""
    return os.path.join(pasta, "brutos", base, nome)


def gravar_bruto(corpo, caminho):
    """Grava os bytes exatamente como vieram da ANAC.

    Escreve num .parcial e so entao renomeia: uma coleta interrompida nao
    deixa um arquivo pela metade com o nome definitivo, que a rodada
    seguinte pularia como se estivesse completo.
    """
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    parcial = caminho + ".parcial"
    with open(parcial, "wb") as arquivo:
        arquivo.write(corpo)
    os.replace(parcial, caminho)


def vazio(corpo, linhas_cabecalho):
    """Arquivo sem nenhuma linha de dado: so o cabecalho, ou nem isso."""
    return len([linha for linha in corpo.splitlines() if linha.strip()]) <= linhas_cabecalho


def alvos(base, desde=None, ate=None):
    """O que coletar de uma base: (periodo, nome local) de cada arquivo.

    Na base mensal, um por mes, com nome local AAAAMM.csv qualquer que seja
    o nome na ANAC. Na fixa, os arquivos do FONTES, sem periodo.
    """
    fonte = FONTES[base]
    if fonte["tipo"] == "mensal":
        return [(str(mes), f"{mes}.csv") for mes in gerar_meses(desde or fonte["desde"], ate)]
    return [("", nome) for nome in fonte["arquivos"]]


def coletar_base(base, desde=None, ate=None, pasta=PASTA_DADOS, revisar=False):
    """Baixa o que falta de uma base. Devolve um registro por arquivo.

    Mes ja baixado e pulado, a nao ser com `revisar`, que baixa de novo pra
    ver se a ANAC trocou o arquivo. Arquivo fixo e sempre baixado de novo:
    e o retrato mais recente (o acumulado ganha um mes a cada publicacao).
    Arquivo vazio nao e gravado.
    """
    fonte = FONTES[base]
    registros = []
    for periodo, nome in alvos(base, desde, ate):
        caminho = caminho_bruto(base, nome, pasta)
        registro = {"base": base, "periodo": periodo, "arquivo": nome, "url": "", "baixado": False}
        if fonte["tipo"] == "mensal" and os.path.exists(caminho) and not revisar:
            registros.append({**registro, "situacao": "ok"})
            continue

        if fonte["tipo"] == "mensal":
            resultado, corpo, url = baixar_mes(base, int(periodo))
        else:
            url = fonte["arquivos"][nome]
            resultado, corpo = buscar(url)
        if resultado == "ok" and vazio(corpo, fonte["linhas_cabecalho"]):
            resultado = "vazio"
        if resultado == "ok":
            gravar_bruto(corpo, caminho)
            registro.update(bytes=len(corpo), sha256=hashlib.sha256(corpo).hexdigest())
        registros.append({**registro, "situacao": resultado, "url": url, "baixado": resultado == "ok"})
        time.sleep(PAUSA)
    return registros


def ler_csv(caminho):
    """Linhas de um CSV do projeto. Arquivo ausente vira lista vazia."""
    if not os.path.exists(caminho):
        return []
    with open(caminho, newline="", encoding="utf-8") as arquivo:
        return list(csv.DictReader(arquivo))


def gravar_csv(linhas, colunas, caminho):
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    with open(caminho, "w", newline="", encoding="utf-8") as arquivo:
        # \n em qualquer sistema: o padrao do csv e \r\n, e no Linux do
        # GitHub Actions o arquivo inteiro apareceria alterado (licao do MED)
        escritor = csv.DictWriter(arquivo, fieldnames=colunas, lineterminator="\n")
        escritor.writeheader()
        escritor.writerows(linhas)


def atualizar_manifesto(registros, pasta=PASTA_DADOS, hoje=None):
    """Acrescenta ao manifesto cada arquivo baixado com um sha256 que ele
    ainda nao tem pra mesma base e arquivo. Devolve (linhas novas,
    revisados).

    O manifesto e o arquivo da coleta: guarda tamanho, sha256, data e URL
    de cada versao baixada, enquanto os brutos ficam fora do git. Sha256
    novo num arquivo que ja estava no manifesto e revisao da ANAC: as duas
    versoes ficam registradas, e o bruto fica com a mais nova. Sem linha
    nova, o arquivo nem e regravado, pra rodada sem novidade nao virar
    mudanca no git.
    """
    hoje = hoje or date.today().isoformat()
    caminho = os.path.join(pasta, MANIFESTO)
    linhas = ler_csv(caminho)
    conhecidos = {(l["base"], l["arquivo"], l["sha256"]) for l in linhas}
    ja_registrados = {(l["base"], l["arquivo"]) for l in linhas}
    novas, revisados = [], []
    for r in registros:
        chave = (r["base"], r["arquivo"], r.get("sha256"))
        if not r["baixado"] or chave in conhecidos:
            continue
        conhecidos.add(chave)
        if (r["base"], r["arquivo"]) in ja_registrados:
            revisados.append((r["base"], r["arquivo"]))
        novas.append({
            "base": r["base"], "periodo": r["periodo"], "arquivo": r["arquivo"],
            "bytes": str(r["bytes"]), "sha256": r["sha256"], "coletado_em": hoje, "url": r["url"],
        })
    if novas:
        ordem = lambda l: (l["base"], l["periodo"], l["arquivo"], l["coletado_em"], l["sha256"])
        gravar_csv(sorted(linhas + novas, key=ordem), COLUNAS_MANIFESTO, caminho)
    return novas, revisados


def gravar_cobertura(registros, pasta=PASTA_DADOS):
    """Grava dados/cobertura.csv: a situacao de cada arquivo na ultima
    coleta que passou por ele.

    situacao: ok, vazio, erro_403, erro_404, erro_5xx, falha_rede ou
    erro_<codigo>. Uma coleta parcial (uma base so, ou --desde) troca so as
    linhas por onde passou e mantem as outras. Sem data no arquivo, pra
    rodada sem novidade dar o mesmo arquivo, byte a byte.
    """
    caminho = os.path.join(pasta, COBERTURA)
    chave = lambda l: (l["base"], l["periodo"], l["arquivo"])
    linhas = {chave(l): l for l in ler_csv(caminho)}
    for r in registros:
        linhas[chave(r)] = {coluna: r[coluna] for coluna in COLUNAS_COBERTURA}
    gravar_csv(sorted(linhas.values(), key=chave), COLUNAS_COBERTURA, caminho)


def erros(registros):
    """Os registros que fazem a coleta sair com erro.

    Conta qualquer situacao diferente de ok e vazio, menos o 404 de uma
    base mensal depois do ultimo mes que veio: e mes que ainda nao saiu. Um
    404 antes desse mes e buraco na serie, e conta. Se nenhum mes da base
    veio, todo 404 conta: no MED, uma rodada sem nada ok terminava verde.
    """
    ultimo = {}
    for r in registros:
        if r["situacao"] in ("ok", "vazio"):
            ultimo[r["base"]] = max(ultimo.get(r["base"], ""), r["periodo"])
    problemas = []
    for r in registros:
        if r["situacao"] in ("ok", "vazio"):
            continue
        ainda_nao_saiu = (
            r["situacao"] == "erro_404"
            and FONTES[r["base"]]["tipo"] == "mensal"
            and r["base"] in ultimo
            and r["periodo"] > ultimo[r["base"]]
        )
        if not ainda_nao_saiu:
            problemas.append(r)
    return problemas


def main(argv):
    parser = argparse.ArgumentParser(description="Coletor das bases da ANAC do voos-em-numeros")
    parser.add_argument("base", nargs="?", choices=sorted(FONTES) + ["todas"], help="base a coletar, ou todas")
    parser.add_argument("--desde", type=int, help="primeiro mes das bases mensais, AAAAMM (padrao: 201901)")
    parser.add_argument("--ate", type=int, help="ultimo mes das bases mensais, AAAAMM (padrao: o corrente)")
    parser.add_argument("--revisar", action="store_true", help="baixa de novo os meses ja baixados, pra achar revisao")
    parser.add_argument("--listar", action="store_true", help="lista as bases e sai")
    args = parser.parse_args(argv)

    if args.listar or not args.base:
        for nome, fonte in FONTES.items():
            if fonte["tipo"] == "mensal":
                print(f"{nome:13} mensal, desde {fonte['desde']}")
            else:
                print(f"{nome:13} {', '.join(fonte['arquivos'])}")
        return 0

    registros = []
    for base in (sorted(FONTES) if args.base == "todas" else [args.base]):
        da_base = coletar_base(base, args.desde, args.ate, revisar=args.revisar)
        registros += da_base
        situacoes = Counter(r["situacao"] for r in da_base)
        resumo = ", ".join(f"{qtde} {situacao}" for situacao, qtde in sorted(situacoes.items()))
        print(f"{base}: {resumo}; {sum(r['baixado'] for r in da_base)} baixados agora")

    problemas = erros(registros)
    if not any(r["situacao"] in ("ok", "vazio") for r in registros):
        # nada veio: nao regrava nada, pra uma rodada que falhou inteira nao
        # aparecer como mudanca no git
        print("nada coletado; nenhum arquivo gravado")
        return 1

    _, revisados = atualizar_manifesto(registros)
    gravar_cobertura(registros)
    for base, arquivo in revisados:
        print(f"revisado pela ANAC: {base}/{arquivo}")
    for r in problemas:
        print(f"ERRO {r['base']} {r['periodo'] or r['arquivo']}: {r['situacao']}")
    return 1 if problemas else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

