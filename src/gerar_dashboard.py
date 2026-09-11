# -*- coding: utf-8 -*-
"""Injeta a logo e as fontes (base64) no template e grava o dashboard final."""
import base64
import pathlib

RAIZ = pathlib.Path(__file__).resolve().parent.parent
FONTES = RAIZ / "assets" / "fonts"

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


logo = (RAIZ / "assets" / "logo_b64.txt").read_text(encoding="utf-8").strip()
html = (RAIZ / "src" / "dashboard_template.html").read_text(encoding="utf-8")
html = html.replace("{{LOGO_B64}}", logo).replace("{{FONTS_CSS}}", css_fontes())
saida = RAIZ / "entregaveis" / "DRE_Dashboard.html"
saida.parent.mkdir(exist_ok=True)
saida.write_text(html, encoding="utf-8", newline="\n")
print(f"gerado: {saida}  ({saida.stat().st_size/1024:.0f} KB)")
