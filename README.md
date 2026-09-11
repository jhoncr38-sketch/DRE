# DRE + Reforma Tributária — Alexandre Araújo Consultoria & Contabilidade

Sistema que transforma a DRE crua de um cliente em dois entregáveis com a identidade
do escritório: uma **planilha Excel** (modelo reutilizável, protegida) e um
**dashboard web** (arquivo único, compartilhável por link).

Contexto: escritório de contabilidade que atende clientes de **vários ramos**
(farmácia, construção civil, transporte, advocacia). O sistema calcula a DRE e a
memória de cálculo da **CBS** da reforma tributária.

---

## Como rodar

```bash
pip install openpyxl pillow          # + LibreOffice para o PDF

python3 src/build.py                 # build/styled_nochart.xlsx  (estrutura + estilos)
python3 src/add_charts.py            # build/final.xlsx           (4 gráficos)
python3 src/finalize.py              # impressão, proteção, instruções
python3 src/exportar.py              # recalcula e gera .xlsx + .pdf em entregaveis/
python3 src/gerar_dashboard.py       # entregaveis/DRE_Dashboard.html
```

Os scripts resolvem os caminhos a partir da raiz do projeto — rodam de qualquer
diretório. Intermediários vão para `build/` (ignorado no git); os finais para
`entregaveis/`.

### Teste de regressão

```bash
python3 -c "
import openpyxl
v=openpyxl.load_workbook('entregaveis/DRE_Aragao_Apresentacao.xlsx',data_only=True)
m=v['MÊS-DEZEMBRO']
assert abs(m['J21'].value-3536.69)<.02   # débito total
assert abs(m['J30'].value-2721.14)<.02   # crédito total
assert abs(m['J32'].value-815.54)<.02    # CBS a pagar
assert abs(m['J15'].value-4140.30)<.02   # Simples sem a CBS
print('OK')"
```

---

## Estrutura

```
src/
  build.py                 # monta as 3 abas do xlsx: CONFIGURAÇÃO, ANUAL, MÊS-DEZEMBRO
  add_charts.py            # 4 gráficos nativos do Excel, cores da marca
  finalize.py              # impressão A4, proteção de células, caixa de instruções
  exportar.py              # recalcula via LibreOffice e gera o PDF
  gerar_dashboard.py       # injeta a logo e as fontes (base64) no template
  dashboard_template.html  # dashboard completo (1 arquivo, sem dependências externas)
assets/
  logo.png / logo_crop.png / logo_b64.txt
  fonts/                   # IBM Plex Sans (variável) + Mono 400/500/600, subconjunto latin (OFL)
design_handoff_painel_dre/ # referência de design do painel (não é código de produção)
dados-originais/
  DRE_Farmacia_DEZEMBRO.xlsx   # planilha original do cliente (dezembro)
  DRE_Farmacia_JULHO.xlsx      # outro mês — contém erros, ver seção "Julho"
entregaveis/
  DRE_Aragao_Apresentacao.xlsx / .pdf
  DRE_Dashboard.html
```

---

## Identidade visual

Extraída da logo do escritório:

| Token | Valor | Uso |
|---|---|---|
| grafite | `#262626` | textos, faixas, barras neutras |
| vermelho | `#A80201` | destaques, cabeçalho, resultado |
| amarelo | `#FFF3CC` | **células editáveis / premissas** |

Essa tabela vale para o **Excel/PDF** (fonte Arial).

O **dashboard** segue os tokens do handoff `design_handoff_painel_dre/`: texto `#14161A`,
reforma/CBS `#B3122B` (o vermelho só aparece em valores da reforma e no foco), fundo
`#EFEEEA`, IBM Plex Sans na interface e IBM Plex Mono em todos os números. Cantos retos,
sem sombras. Só tema claro.

**Cuidado:** as cores personalizáveis são `--fill` (preenchimentos: bloco herói, aba
ativa, barra "hoje", faixa do resultado) e `--brand`. O texto usa `--ink`, que nunca
muda. Já foram unificados por engano uma vez e o texto ficou ilegível.

---

## Planilha (xlsx)

### Aba CONFIGURAÇÃO
Três campos amarelos: nome da empresa, período anual, mês de referência.
Os cabeçalhos das outras abas são **fórmulas** que leem daqui:

```
="DEMONSTRAÇÃO DE RESULTADO — DRE"&CHAR(10)&CONFIGURAÇÃO!$B$3&CHAR(10)&CONFIGURAÇÃO!$B$4
```

### Aba MÊS-DEZEMBRO — layout de colunas

| Col | Conteúdo |
|---|---|
| A | Descrição da conta |
| B | Valor (R$) |
| C | **% da base com direito a crédito** (editável) |
| D | **Alíquota CBS** (editável) |
| E | Crédito (R$) = `B × C × D` |
| F | espaçador |
| G–J | Memória de cálculo da reforma (rótulo, base, alíquota, valor) |
| N–O | Dados auxiliares dos gráficos (fora da área de impressão) |

### Memória de cálculo (G–J), linhas fixas

```
 7  Receita
 8  Simples Nacional
 9  Alíquota efetiva (Simples ÷ Receita)   <- CALCULADA
10  % da CBS sobre a efetiva  (15,33%)     <- EDITÁVEL
11  Percentual da CBS = J9 × J10
12  Percentual ICMS  = J9 × 33,5%
13  Alíquota efetiva líq. ICMS = J9 − J12
14  Valor de CBS = J7 × (J11/100)
15  Simples sem a CBS = J8 − J14
16  [cabeçalho] DÉBITO — receita tributada
17-20  categorias de receita  (nome/base/alíquota editáveis, 4 linhas)
21  Débito total
23  [cabeçalho] CRÉDITO
24  Crédito geral (despesas)  = E{linha subtotal G&A}
25-28  créditos sobre compras (4 linhas)
29  Saldo credor do mês anterior           <- EDITÁVEL
30  Crédito total
32  CBS A PAGAR = MAX(0, débito − crédito)
33  Saldo credor a transportar = MAX(0, crédito − débito)
35+ Memória RBT12 (referência) e valor avulso herdado
```

### Proteção
`finalize.py` trava tudo que é fórmula e libera ~238 células de digitação
(colunas B–E do mês, B da anual, todas as amarelas, a aba CONFIGURAÇÃO).
Sem senha — Revisão → Desproteger Planilha.

---

## Dashboard (dashboard_template.html)

Arquivo único, sem CDN, sem build. Logo e fontes embutidas em base64
(`{{LOGO_B64}}`, `{{FONTS_CSS}}`). Barras em HTML/CSS, sem biblioteca.

- **Cabeçalho e faixa de indicadores** fixos em todas as abas: um número dominante
  (resultado líquido) e três de apoio
- **Abas:** Resultado · Reforma · CBS · Resumo do cliente (mês) · Anual; setas do teclado navegam
- **Detalhamento** recolhível (despesas com % base/alíquota/crédito e tributárias)
- **Premissas** "Alíquota geral" e "reduzida" propagam para as linhas; o rótulo da reduzida
  é o nome da primeira categoria de débito reduzida (ex.: Medicamentos)
- **Menu Opções:** Editar valores, Personalizar (nome, períodos, rodapé, 2 cores, logo),
  Modo apresentação, Imprimir, Salvar, Baixar HTML, Restaurar padrão, Limpar tudo
- **Limpar tudo:** dois cliques; zera valores e mantém categorias, alíquotas, premissas e identidade
- **Modo apresentação** e link `#cliente` (abre no Resumo do cliente) deixam os campos só leitura
- **Salvar:** `window.storage` (chave `dre_state`, `shared=true`)
- **Baixar HTML:** grava o estado num `<script id="estado-salvo">` no `<head>`, inserido pelo DOM

### Como a tela atualiza
`render()` monta a estrutura (troca de aba, adicionar/remover linha, detalhamento).
`refresh()` recalcula e escreve só os textos marcados com `data-o`, as larguras das barras
(`data-w`) e os campos fora de foco — por isso digitar recalcula tudo sem perder o cursor.
Campos: `data-b` = caminho no estado, `data-f` = formato (`brl`, `base`, `pct`, `pct0`, `txt`).
Parser pt-BR `num()`: com vírgula, ela é o decimal; sem vírgula, o ponto é decimal.

### Restrição importante
**Não usar `localStorage`/`sessionStorage`** — não funcionam no ambiente de artifacts.
Estado vive em memória + `window.storage`.

### Modelo de dados (`defaults()`, `v: 2`)
```js
monthly.ga = [ [label, valor, %base, alíquota], ... ]   // crédito por item
monthly.reforma = {
  aliqGeral, aliqReduzida, cbsSobreEfetiva, saldoCredorAnterior,
  debitos:  [ [nome, base, alíquota, 'geral'|'reduzida'], ... ],   // categorias de receita
  creditos: [ [nome, base, alíquota, 'geral'|'reduzida'], ... ]    // créditos sobre compras
}
```
Estados salvos no modelo antigo (v1: `creditosCompra`, `creditoGeralAliq`, sem tipo) são
migrados em `migrar()` e mesclados em profundidade com os padrões.

"Simples sem a CBS" é **calculado** (Simples × parcela da CBS, campo editável no cartão de
carga tributária), não constante como no handoff — com 15,33% dá os mesmos 4.140,30.

As categorias são **editáveis e ilimitadas** justamente porque o escritório
atende ramos diferentes — não pode haver "medicamento" hardcoded.

---

## Regras de negócio confirmadas com o contador

1. **Alíquota efetiva = Simples pago no mês ÷ Receita do mês.**
   Validado nos dois meses: julho 1.184,90 ÷ 11.114,64 = 10,66%;
   dezembro 4.889,93 ÷ 106.419,89 = 4,59%.
2. **Percentual da CBS = efetiva × 15,33%** (campo editável — ver pendência 3).
3. **Simples sem a CBS = Simples − Valor de CBS.**
4. **Saldo credor acumula** para o mês seguinte. Nunca exibir CBS a pagar negativo:
   mostrar `CBS a pagar = 0` + `Saldo credor a transportar`.
5. **Crédito por item:** cada despesa tem % da base com direito e alíquota própria
   (aluguel 30%, contabilidade 70%, pessoal 0%, demais 100%).
6. Comparação da carga = **Hoje (Simples)** × **Simples sem a CBS** × **Na transição**
   (Simples sem CBS + CBS + IBS).

### Números de referência (dezembro) — usar como teste de regressão
```
Receita          106.419,89     Débito total        3.536,69
Simples            4.889,93     Crédito total       2.721,14
Lucro bruto       48.380,29     CBS a pagar           815,54
Resultado         16.988,25     Simples sem a CBS   4.140,30
```
Anual: receita 1.187.289,06 · custos 699.636,26 · G&A 308.172,88 ·
tributárias 109.016,62 · resultado informado 81.289,32.

---

## Pendências (ordem sugerida)

1. **Divergência de R$ 10.922,02 no resultado anual.** O valor informado
   (81.289,32) não bate com a soma das linhas (70.367,30). Mantido o informado,
   com comentário na célula e nota no dashboard. **Não resolvido — é do cliente.**

2. **IBS ausente.** O sistema só calcula CBS. A barra "Na transição" está
   incompleta e **subestima** a carga. Há campo de entrada manual do IBS.
   Falta também o cronograma de transição.

3. **15,33% × 15,5%.** A memória RBT12 do cliente usa 15,5% para a mesma conta.
   Deixado editável até ele decidir.

4. **Plano de contas diferente entre as abas.** Anual tem "Fatura Cartão",
   "Funcionários"; mensal tem "HapVida", "Folha". Impede somar meses no anual.

5. **Multi-mês.** Hoje é um mês por arquivo — foi o que gerou os erros de julho.
   Doze meses juntos resolveriam anual por soma, saldo credor automático e evolução.

6. **Validações automáticas.** Ver seção seguinte — é o maior ganho pendente.

7. **Reclassificações que distorcem o resultado:** retirada de sócio como despesa
   operacional; INSS/FGTS em "Despesas Tributárias" em vez de custo de pessoal;
   parcelamentos (dívida antiga) misturados à operação do mês.

---

## Julho — erros encontrados no arquivo do cliente

Servem de caso de teste para as validações automáticas:

| Erro | Detalhe |
|---|---|
| Crédito geral fixo | 639,86 digitado (valor de **dezembro**); a coluna de julho soma 147,25 |
| Compra de outro mês | `B50 = 62.239,31` rotulada **"DEZ"**; inventário 25/11/2025 |
| Débito errado | `=SUM(C2:C64)` soma a coluna de **créditos** e conta o subtotal 2× → 302,50 |
| Referência vazia | `débito total = F12 + F13`, F12 vazia |
| Soma que pula linha | `C29 = SUM(C15:C28)` deixa de fora o crédito de vendas (C34 = 8,00) |
| Consequência | CBS a pagar = **−2.418,65** (negativo) |

### Validações a implementar
- crédito geral digitado ≠ soma da coluna
- data/rótulo de compra ou inventário fora do mês de referência
- base de débito referenciando coluna de crédito
- referência vazia dentro de um total
- intervalo de soma que não cobre todas as linhas do bloco
- receita tributada (soma das categorias) ≠ receita declarada no PGDAS
- resultado informado ≠ soma das linhas

Formato sugerido: painel no topo — verde (ok), amarelo (conferir), vermelho (não entregar).

---

## Ideias maiores discutidas

- **Cadastro de clientes com modelo por ramo** — cada ramo traz suas categorias e
  alíquotas padrão; guarda plano de contas e histórico por cliente.
- **Simulação "fico no Simples ou saio?"** — para quem vende a PJ (construção,
  transporte) o crédito ao cliente muda a conta; para varejo a consumidor final
  tende a não compensar.
- **Importar balancete** e mapear contas uma vez por cliente.
- **Google Sheets** como arquivo de trabalho, mantendo o dashboard como entrega.
  Avaliado e adiado. Conversão perde gráficos, logo e proteção — exige retoque.

---

## Armadilhas conhecidas (já custaram retrabalho)

1. Rótulo iniciado com `=` vira fórmula → `#VALUE!`. Usar `(=) Lucro Operacional Bruto`.
2. Formato de moeda precisa do locale: `[$-416]"R$" #,##0.00`, senão o PDF do
   LibreOffice sai como `1,187,289.06`.
3. Altura de linha 16 causa sobreposição no PDF — usar 18.
4. Linhas "espaçadoras" curtas encolhem também o bloco da esquerda (mesma linha).
5. Rótulos de gráfico mostram "Column I" se `showSerName`/`showCatName` não forem
   explicitamente `False`.
6. Itens de CSS grid não encolhem sem `min-width:0` → rolagem lateral no celular.
7. Gráficos e imagens **sobrevivem** ao recalc do LibreOffice.
