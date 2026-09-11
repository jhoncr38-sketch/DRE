# -*- coding: utf-8 -*-
import pathlib as _pl
_RAIZ = _pl.Path(__file__).resolve().parent.parent
_ASSETS = _RAIZ / "assets"
_OUT = _RAIZ / "build"
_OUT.mkdir(exist_ok=True)

import openpyxl
from openpyxl.chart import BarChart, PieChart, Reference, Series
from openpyxl.chart.label import DataLabelList
from openpyxl.chart.marker import DataPoint
from openpyxl.drawing.fill import PatternFillProperties
from openpyxl.chart.shapes import GraphicalProperties
from openpyxl.drawing.line import LineProperties

RED="A80201"; CHAR="262626"; MGRAY="9E9E9E"; REDL="D98C8B"; GRAY2="6E6E6E"

def gp(hexc):
    g=GraphicalProperties(solidFill=hexc)
    g.line=LineProperties(solidFill="FFFFFF", w=9525)
    return g

wb=openpyxl.load_workbook(str(_OUT / "styled_nochart.xlsx"))

# ---------------- ANUAL ----------------
ws=wb["ANUAL"]
# Pie: composition (H4:I8)
pie=PieChart()
pie.title="Para onde vai cada real da receita"
pie.height=7.6; pie.width=15.5
data=Reference(ws, min_col=9, min_row=4, max_row=8)
cats=Reference(ws, min_col=8, min_row=4, max_row=8)
pie.add_data(data, titles_from_data=False)
pie.set_categories(cats)
s=pie.series[0]
pie_colors=[CHAR, RED, GRAY2, REDL, MGRAY]
s.data_points=[DataPoint(idx=i, spPr=gp(c)) for i,c in enumerate(pie_colors)]
pie.dataLabels=DataLabelList()
pie.dataLabels.showPercent=True
pie.dataLabels.showVal=False
pie.dataLabels.showCatName=False
pie.dataLabels.showSerName=False
pie.dataLabels.showLegendKey=False
pie.dataLabels.numFmt="[$-416]0.0%"
ws.add_chart(pie, "A54")

# Column: result overview (H10:I14)
bar=BarChart(); bar.type="col"; bar.title="Resultado — visão geral (Anual)"
bar.height=7.6; bar.width=15.5; bar.legend=None
d2=Reference(ws, min_col=9, min_row=10, max_row=14)
c2=Reference(ws, min_col=8, min_row=10, max_row=14)
bar.add_data(d2, titles_from_data=False); bar.set_categories(c2)
sb=bar.series[0]
col_colors=[RED, GRAY2, CHAR, GRAY2, RED]
sb.data_points=[DataPoint(idx=i, spPr=gp(c)) for i,c in enumerate(col_colors)]
bar.dataLabels=DataLabelList()
bar.dataLabels.showVal=True
bar.dataLabels.showSerName=False
bar.dataLabels.showCatName=False
bar.dataLabels.showLegendKey=False
bar.dataLabels.numFmt="[$-416]\"R$\" #,##0"
bar.y_axis.numFmt="[$-416]\"R$\" #,##0"; bar.y_axis.majorGridlines=None
ws.add_chart(bar, "A70")

# ---------------- MÊS ----------------
ws2=wb["MÊS-DEZEMBRO"]
# Comparison Atual x Reforma (H6:I7)
cmp=BarChart(); cmp.type="col"; cmp.title="Carga Tributária Mensal — Hoje x Transição"
cmp.height=7.6; cmp.width=15.5; cmp.legend=None
dc=Reference(ws2, min_col=15, min_row=6, max_row=8)
cc=Reference(ws2, min_col=14, min_row=6, max_row=8)
cmp.add_data(dc, titles_from_data=False); cmp.set_categories(cc)
sc=cmp.series[0]
sc.data_points=[DataPoint(idx=0, spPr=gp(CHAR)), DataPoint(idx=1, spPr=gp(GRAY2)), DataPoint(idx=2, spPr=gp(RED))]
cmp.dataLabels=DataLabelList()
cmp.dataLabels.showVal=True
cmp.dataLabels.showSerName=False
cmp.dataLabels.showCatName=False
cmp.dataLabels.showLegendKey=False
cmp.dataLabels.numFmt="[$-416]\"R$\" #,##0.00"
cmp.y_axis.numFmt="[$-416]\"R$\" #,##0"; cmp.y_axis.majorGridlines=None
ws2.add_chart(cmp, "A50")

# CBS mechanic (H10:I12)
mech=BarChart(); mech.type="col"; mech.title="CBS — Débito, Crédito e Saldo a Pagar"
mech.height=7.6; mech.width=15.5; mech.legend=None
dm=Reference(ws2, min_col=15, min_row=10, max_row=12)
cm=Reference(ws2, min_col=14, min_row=10, max_row=12)
mech.add_data(dm, titles_from_data=False); mech.set_categories(cm)
sm=mech.series[0]
sm.data_points=[DataPoint(idx=0, spPr=gp(CHAR)), DataPoint(idx=1, spPr=gp(GRAY2)), DataPoint(idx=2, spPr=gp(RED))]
mech.dataLabels=DataLabelList()
mech.dataLabels.showVal=True
mech.dataLabels.showSerName=False
mech.dataLabels.showCatName=False
mech.dataLabels.showLegendKey=False
mech.dataLabels.numFmt="[$-416]\"R$\" #,##0.00"
mech.y_axis.numFmt="[$-416]\"R$\" #,##0"; mech.y_axis.majorGridlines=None
ws2.add_chart(mech, "A66")

wb.save(str(_OUT / "final.xlsx"))
print("charts added -> final.xlsx")
