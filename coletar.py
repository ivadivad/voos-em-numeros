"""Coletor das bases da ANAC usadas no projeto.

Baixa os arquivos como a ANAC publica, sem mexer no conteudo, para
dados/brutos/<base>/. O que cada base e, linha a linha, esta no
DICIONARIO.md; aqui fica so onde buscar cada arquivo e como ele chega.

So biblioteca padrao: roda em qualquer Python 3, sem pip install.
"""
import http.client
import urllib.error
import urllib.parse
import urllib.request

# o gov.br devolve 403 pro User-Agent padrao do urllib (Python-urllib/3.x);
# com um que identifica o projeto, devolve a pagina
USER_AGENT = "voos-em-numeros/0.1 (+https://github.com/ivadivad/voos-em-numeros)"

VRA ="https://sistemas.anac.gov.br/dadosabertos/Voos e operações aéreas/Voo Regular Ativo (VRA)"
DADOS_ABERTOS = "https://sistemas.anac.gov.br/dadosabertos"

# por base: o tipo ("mensal" = um arquivo por mes; "fixo" = arquivos sem
# mes, sempre na versao mais recente), onde buscar e como o arquivo chega.
# separador, encoding e linhas_cabecalho sao os conferidos na etapa 1.
FONTES = {
    "tarifas": {
        "tipo": "mensal",
        "url": "https://sas.anac.gov.br/sas/tarifadomestica/{ano}/{ano}{mes:02d}.csv",
        # formulario do DataSAS com a lista oficial de arquivos de cada ano:
        # mai/2026 so existe la, como "202605 (1).CSV"
        "listagem": "https://sas.anac.gov.br/sas/downloads/view/frmDownload.aspx?tema=14",
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

# nomes das pastas mensais do VRA ("03 - Março")
MESES = [
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
]


def baixar(url, timeout=120):
    """Faz um GET e devolve (status, bytes). Nunca levanta excecao por
    problema de rede ou do servidor.

    status None quer dizer que nem chegou resposta inteira: timeout,
    conexao recusada ou derrubada no meio do arquivo (o servidor da ANAC
    faz isso). Acento, espaco e parentese viram %XX aqui, entao FONTES
    guarda a URL legivel; uma URL ja codificada passa sem mudar.
    """
    pedido = urllib.request.Request(
        urllib.parse.quote(url, safe=":/?=&%"), headers={"User-Agent": USER_AGENT}
    )
    try:
        with urllib.request.urlopen(pedido, timeout=timeout) as resposta:
            return resposta.status, resposta.read()
    except urllib.error.HTTPError as erro:
        return erro.code, b""
    except (OSError, http.client.HTTPException):
        # HTTPException: IncompleteRead quando a conexao cai no meio do corpo
        return None, b""
