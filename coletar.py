"""Coletor das bases da ANAC usadas no projeto.

Baixa os arquivos como a ANAC publica, sem mexer no conteudo, para
dados/brutos/<base>/. O que cada base e, linha a linha, esta no
DICIONARIO.md; aqui fica so onde buscar cada arquivo e como ele chega.

So biblioteca padrao: roda em qualquer Python 3, sem pip install.
"""
import functools
import http.client
import os
import time
import urllib.error
import urllib.parse
import urllib.request
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


@functools.lru_cache(maxsize=None)
def listar_datasas(url, ano):
    """Lista os arquivos de um ano no DataSAS. Devolve (situacao, arquivos),
    com cada arquivo como (AAAAMM, nome).

    O DataSAS e um formulario ASP.NET: a lista so aparece depois de enviar
    o ano junto com os campos ocultos da pagina (__VIEWSTATE e afins), na
    mesma sessao. Guardado em cache: um ano so e consultado uma vez por
    rodada.
    """
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
    return "ok", tuple(arquivos_do_datasas(resposta.decode("utf-8", "replace")))


def achar_na_listagem(base, mes):
    """URL do arquivo de um mes segundo a listagem oficial, ou None.

    Serve pro que o padrao de URL nao acha: mai/2026 das tarifas so existe
    como "202605 (1).CSV". Nas tarifas, a lista do ano vem do DataSAS; no
    VRA, da listagem da pasta do mes.
    """
    ano = mes // 100
    if base == "tarifas":
        _, arquivos = listar_datasas(FONTES["tarifas"]["listagem"], ano)
        candidatos = [nome for referencia, nome in arquivos if referencia == mes]
        pasta = FONTES["tarifas"]["pasta"].format(ano=ano)
    else:
        pasta = montar_url(base, mes, chave="listagem")
        resultado, pagina = buscar(pasta)
        nomes = arquivos_da_pasta(pagina.decode("utf-8", "replace")) if resultado == "ok" else []
        candidatos = [n for n in nomes if n.lower().endswith(".csv")]
    return pasta + sorted(candidatos)[0] if candidatos else None


def baixar_mes(base, mes):
    """Baixa o arquivo de um mes. Devolve (situacao, bytes, url usada).

    Tenta o padrao de URL; se der 404, procura o mes na listagem oficial
    antes de concluir que ele nao foi publicado.
    """
    url = montar_url(base, mes)
    resultado, corpo = buscar(url)
    if resultado == "erro_404":
        alternativa = achar_na_listagem(base, mes)
        if alternativa:
            url = alternativa
            resultado, corpo = buscar(url)
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


def coletar_base(base, desde=None, ate=None, pasta=PASTA_DADOS):
    """Baixa o que falta de uma base. Devolve um registro por arquivo.

    Mes ja baixado e pulado. Arquivo fixo e sempre baixado de novo: e o
    retrato mais recente (o acumulado ganha um mes a cada publicacao).
    Arquivo vazio nao e gravado.
    """
    fonte = FONTES[base]
    registros = []
    for periodo, nome in alvos(base, desde, ate):
        caminho = caminho_bruto(base, nome, pasta)
        registro = {"base": base, "periodo": periodo, "arquivo": nome, "url": "", "baixado": False}
        if fonte["tipo"] == "mensal" and os.path.exists(caminho):
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
        registros.append({**registro, "situacao": resultado, "url": url, "baixado": resultado == "ok"})
        time.sleep(PAUSA)
    return registros
