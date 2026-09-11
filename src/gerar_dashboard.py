# -*- coding: utf-8 -*-
"""Injeta a logo e as fontes (base64) no template e grava o dashboard final.

entregaveis/DRE_Dashboard.html sai SEM a configuração do Supabase (vai para o GitHub).
Se houver SUPABASE_URL e SUPABASE_ANON_KEY no .env (ou no ambiente), grava também
build/DRE_Dashboard_banco.html, já ligado ao banco, para usar no computador.
Na Vercel, quem liga o banco é scripts/vercel_build.mjs.
"""
import base64
import json
import os
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
FONTES = RAIZ / "assets" / "fonts"
MARCA_SUPABASE = "/*SUPABASE_CONFIG*/null"

# IBM Plex (SIL Open Font License 1.1), só o subconjunto latin do Google Fonts.
# A Sans é variável: um arquivo cobre todos os pesos.
TABELA_FONTES = [
    ("IBM Plex Sans", "100 700", "IBMPlexSans-latin-var.woff2"),
    ("IBM Plex Mono", "400", "IBMPlexMono-latin-400.woff2"),
    ("IBM Plex Mono", "500", "IBMPlexMono-latin-500.woff2"),
    ("IBM Plex Mono", "600", "IBMPlexMono-latin-600.woff2"),
]


def css_fontes() -> str:
    blocos = []
    for familia, peso, arquivo in TABELA_FONTES:
        b64 = base64.b64encode((FONTES / arquivo).read_bytes()).decode("ascii")
        blocos.append(
            f"@font-face{{font-family:'{familia}';font-style:normal;font-weight:{peso};"
            f"font-display:swap;src:url(data:font/woff2;base64,{b64}) format('woff2')}}"
        )
    return "\n".join(blocos)


def ler_env() -> dict:
    """Variáveis do .env da raiz (se existir); as do ambiente têm prioridade."""
    valores = {}
    arquivo = RAIZ / ".env"
    if arquivo.exists():
        for linha in arquivo.read_text(encoding="utf-8").splitlines():
            linha = linha.strip()
            if not linha or linha.startswith("#") or "=" not in linha:
                continue
            nome, valor = linha.split("=", 1)
            valores[nome.strip()] = valor.strip().strip('"').strip("'")
    for nome in ("SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEY"):
        if os.environ.get(nome):
            valores[nome] = os.environ[nome]
    return valores


def chave_secreta(chave: str) -> bool:
    if chave.startswith("sb_secret_"):
        return True
    partes = chave.split(".")
    if len(partes) != 3:
        return False
    try:
        carga = base64.urlsafe_b64decode(partes[1] + "=" * (-len(partes[1]) % 4))
        return json.loads(carga).get("role") == "service_role"
    except (ValueError, json.JSONDecodeError):
        return False


logo = (RAIZ / "assets" / "logo_b64.txt").read_text(encoding="utf-8").strip()
html = (RAIZ / "src" / "dashboard_template.html").read_text(encoding="utf-8")
html = html.replace("{{LOGO_B64}}", logo).replace("{{FONTS_CSS}}", css_fontes())
if MARCA_SUPABASE not in html:
    sys.exit(f"ERRO: o marcador {MARCA_SUPABASE} sumiu do template.")

saida = RAIZ / "entregaveis" / "DRE_Dashboard.html"
saida.parent.mkdir(exist_ok=True)
saida.write_text(html, encoding="utf-8", newline="\n")
print(f"gerado: {saida}  ({saida.stat().st_size/1024:.0f} KB)")

env = ler_env()
url = env.get("SUPABASE_URL", "").strip().rstrip("/")
chave = (env.get("SUPABASE_ANON_KEY") or env.get("SUPABASE_PUBLISHABLE_KEY") or "").strip()
if url and chave:
    if chave_secreta(chave):
        sys.exit("ERRO: SUPABASE_ANON_KEY é uma chave SECRETA (service_role). Use a chave pública (anon ou publishable).")
    config = json.dumps({"url": url, "chave": chave}).replace("<", "\\u003c")
    local = RAIZ / "build" / "DRE_Dashboard_banco.html"
    local.parent.mkdir(exist_ok=True)
    local.write_text(html.replace(MARCA_SUPABASE, config, 1), encoding="utf-8", newline="\n")
    print(f"gerado: {local}  (ligado ao Supabase: {url})")
else:
    print("sem .env do Supabase: só a versão local (sem banco) foi gerada")
