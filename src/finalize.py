# -*- coding: utf-8 -*-
import pathlib as _pl
_RAIZ = _pl.Path(__file__).resolve().parent.parent
_ASSETS = _RAIZ / "assets"
_OUT = _RAIZ / "build"
_OUT.mkdir(exist_ok=True)

import openpyxl
from openpyxl.styles import Font, Alignment, PatternFill
from openpyxl.worksheet.properties import PageSetupProperties
from openpyxl.worksheet.pagebreak import Break, RowBreak
from openpyxl.styles import Protection

RED="A80201"; CHAR="262626"; YELLOW="FFF3CC"
wb=openpyxl.load_workbook(str(_OUT / "final.xlsx"))

def setup(ws, print_area, title_rows="1:5", orient="portrait", chart_break=None):
    ws.page_setup.orientation=orient
    ws.page_setup.paperSize=ws.PAPERSIZE_A4
    ws.page_setup.fitToWidth=1
    ws.page_setup.fitToHeight=0
    ws.sheet_properties.pageSetUpPr=PageSetupProperties(fitToPage=True)
    ws.print_options.horizontalCentered=True
    ws.page_margins.left=0.5; ws.page_margins.right=0.5
    ws.page_margins.top=0.45; ws.page_margins.bottom=0.5
    ws.page_margins.header=0.3; ws.page_margins.footer=0.3
    ws.print_area=print_area
    ws.print_title_rows=title_rows
    ws.oddFooter.left.text="Alexandre Araújo — Consultoria & Contabilidade"
    ws.oddFooter.left.size=8; ws.oddFooter.left.color="808080"
    ws.oddFooter.right.text="Página &P de &N"
    ws.oddFooter.right.size=8; ws.oddFooter.right.color="808080"
    ws.sheet_properties.tabColor=RED
    ws.freeze_panes="A7"
    if chart_break:
        rb=RowBreak(); rb.append(Break(id=chart_break)); ws.row_breaks=rb

setup(wb["ANUAL"], "A1:F84")
setup(wb["MÊS-DEZEMBRO"], "A1:J82", orient="landscape", chart_break=49)

# ---- Instructions box (in H column, outside print area) ----
def note(ws, start):
    lines=[
        ("COMO USAR ESTE MODELO", True),
        ("• Células em BRANCO = você digita/atualiza (receita, despesas, compras).", False),
        ("• Linhas em NEGRITO com fundo cinza/escuro = calculadas automaticamente. Não edite.", False),
        ("• Células AMARELAS = premissas da reforma (alíquotas, RBT12, IBS). Edite conforme o caso.", False),
        ("• Ao reaproveitar para outro cliente: troque o nome no cabeçalho e os valores em branco.", False),
        ("• Os gráficos se atualizam sozinhos quando os valores mudam.", False),
    ]
    r=start
    for txt,hd in lines:
        c=ws.cell(row=r, column=(14 if ws.title!="ANUAL" else 8), value=txt)
        c.font=Font(name="Arial", size=9, bold=hd, color=(RED if hd else "404040"))
        c.alignment=Alignment(horizontal="left", vertical="center", wrap_text=False)
        r+=1

note(wb["ANUAL"], 18)
note(wb["MÊS-DEZEMBRO"], 18)

# ---- Proteção: trava fórmulas, libera campos de digitação ----
YELLOW_SET={"FFFFF3CC","00FFF3CC","FFF3CC"}
def is_yellow(c):
    try:
        return c.fill is not None and c.fill.fgColor is not None and str(c.fill.fgColor.rgb) in YELLOW_SET
    except Exception:
        return False

unlocked_total=0
for ws in wb.worksheets:
    data_cols = {"CONFIGURAÇÃO":(2,2), "ANUAL":(2,2), "MÊS-DEZEMBRO":(2,5)}.get(ws.title,(2,2))
    lo,hi = data_cols
    for row in ws.iter_rows():
        for c in row:
            formula = isinstance(c.value,str) and c.value.startswith("=")
            editable = (not formula) and (is_yellow(c) or (lo <= c.column <= hi))
            c.protection = Protection(locked=not editable)
            if editable: unlocked_total+=1
    ws.protection.sheet=True
    ws.protection.enableFormatCells=False
    ws.protection.selectLockedCells=False   # permite selecionar para copiar
    ws.protection.selectUnlockedCells=False

wb.save(str(_OUT / "final.xlsx"))
print("finalized | células liberadas p/ digitação:", unlocked_total)
