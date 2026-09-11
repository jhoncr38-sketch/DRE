# Handoff: Painel DRE — Aragão Produtos Farmacêuticos

## Visão geral
Painel de Demonstração de Resultado (DRE) mensal com simulação da CBS (Reforma Tributária) para um cliente do escritório contábil. Três abas: **Resultado** (a DRE em si), **Reforma · CBS** (memória de cálculo editável + gráficos) e **Resumo do cliente** (versão simplificada, sem detalhamento contábil).

Substitui uma planilha/tela anterior em que quatro cards de topo competiam entre si e todo o detalhamento aparecia de uma vez. Os três problemas atacados foram: hierarquia (onde olhar primeiro), densidade (informação demais junta) e acabamento visual.

## Sobre os arquivos deste pacote
O arquivo `Painel DRE.dc.html` é uma **referência de design em HTML** — um protótipo que mostra aparência e comportamento pretendidos, **não código de produção para copiar**. A tarefa é **recriar este design no ambiente já existente do seu projeto** (React, Vue, etc.), usando os padrões, bibliotecas e convenções que ele já adota. Se o projeto ainda não tem um padrão de UI definido, escolha o framework mais apropriado e implemente lá.

O protótipo usa um runtime próprio de componentes (`support.js`, `<sc-for>`, `<sc-if>`, `renderVals()`). **Nada disso deve ser portado.** O que importa é: a estrutura visual, os tokens, as fórmulas de cálculo e os comportamentos descritos abaixo.

## Fidelidade
**Alta fidelidade (hifi).** Cores, tipografia, espaçamentos e estados estão definitivos. Recrie fielmente, mas usando os componentes do seu design system onde eles existirem.

---

## Design tokens

### Cores
| Token | Hex | Uso |
|---|---|---|
| `ink` | `#14161A` | Texto principal; fundo do bloco de destaque; barras "hoje" |
| `ink-2` | `#33363B` | Texto de linhas de detalhe |
| `ink-3` | `#4A4D53` | Rótulos secundários |
| `muted` | `#6E7178` | Texto de apoio, subtítulos |
| `muted-2` | `#8A8D94` | Percentuais, legendas, metadados |
| `muted-3` | `#9A9DA4` | Texto sobre fundo escuro; barras intermediárias |
| `disabled` | `#B6B8BC` | Valores zerados (crédito R$ 0,00) |
| `brand` | `#B3122B` | **Exclusivo para reforma/CBS**: totais, barra "na transição", foco de input, filete lateral |
| `brand-dark` | `#7d0c1e` | Hover de link |
| `brand-wash` | `#FBF3F4` | Fundo da linha "Lucro operacional bruto" |
| `canvas` | `#EFEEEA` | Fundo da página; trilho vazio das barras |
| `surface` | `#FFFFFF` | Cartões/seções |
| `surface-2` | `#F8F7F4` | Blocos de detalhamento e de premissas |
| `line` | `#E7E5E0` | Divisória de linha de tabela |
| `line-2` | `#DAD8D2` | Borda de cartão, separador de grid |
| `line-3` | `#C7C5BF` | Sublinhado de input em hover/repouso |

**Regra de cor:** o vermelho só aparece em valores ligados à reforma/CBS e no estado de foco. Nunca como decoração.

### Tipografia
- **IBM Plex Sans** (400/500/600/700) — toda a interface
- **IBM Plex Mono** (400/500/600) — **todos os números, sem exceção**, além de rótulos em caixa alta e metadados

| Papel | Tamanho | Peso | Extra |
|---|---|---|---|
| Número herói (resultado líquido) | 52px | 600 | Mono, `letter-spacing:-0.03em`, `line-height:1.05` |
| Número de resumo (cards do cliente) | 26px | 600 | Mono, `-0.02em` |
| Total de seção (CBS a pagar, resultado) | 19px | 600 | Mono |
| Título de seção (h2) | 18px | 600 | `-0.01em` |
| Linha-total da DRE | 15–17px | 600 | valor em Mono |
| Título de cartão (h3) | 15px | 600 | |
| Corpo / linha de tabela | 13–14px | 400 | |
| Input de linha | 13px | 400 | Mono |
| Rótulo em caixa alta | 10–11px | 400 | Mono, `letter-spacing:0.1em–0.12em`, `text-transform:uppercase` |
| Legenda | 11–12px | 400 | |

### Espaçamento e forma
- Grade de espaçamento: 4 / 6 / 8 / 12 / 16 / 20 / 24 / 28 px
- Página: `padding: 28px 24px 64px`, conteúdo `max-width: 1140px` centralizado, `gap: 24px` entre seções
- Cartão: `padding: 26px 28px` (seção larga), `24px 26px` (cartão de gráfico), `40px 44px 36px` (resumo do cliente)
- **Cantos retos.** `border-radius: 2px` apenas em abas e inputs antigos. Sem sombras (exceto `box-shadow: 0 0 0 1px` usado como borda).
- Separação de grid feita por `gap:1px` sobre fundo `#DAD8D2` (linhas hairline reais, não bordas)

---

## Telas

### 1. Cabeçalho (fixo em todas as abas)
Linha com `justify-content: space-between`, `align-items: flex-end`, quebra em telas estreitas.

**Esquerda:** quadrado de 38×38 em `brand` com a inicial "A" em branco 18px/700 → nome do cliente (17px/600, `-0.01em`) → linha de contexto em Mono 12px `muted-2`, caixa alta: `DRE · DEZEMBRO 2025`.

**Direita:** grupo de abas. Trilho `#E3E2DD`, `padding:4px`, `gap:6px`. Aba ativa: fundo `ink`, texto branco. Inativa: fundo transparente, texto `ink-3`. Cada uma `padding:7px 14px`, 13px/500, `border-radius:2px`, sem borda.

Rótulos: **Resultado** · **Reforma · CBS** · **Resumo do cliente**

### 2. Faixa de indicadores (fixa em todas as abas)
`grid-template-columns: minmax(0,1.35fr) minmax(0,1fr); gap:16px`

**Bloco herói (esquerda):** fundo `ink`, texto branco, `padding:26px 28px`. Rótulo em caixa alta Mono 11px `#9A9DA4` → valor 52px Mono/600 → linha de contexto 13px `#C9CCD2`: "margem de X% sobre receita declarada de R$ …".

**Três linhas (direita):** `grid-template-rows: repeat(3,1fr); gap:1px` sobre `#DAD8D2`; cada linha fundo `#F8F7F4`, `padding:12px 18px`, rótulo à esquerda 13px, valor à direita Mono 16px/600 seguido do percentual em 12px `muted-2`.
1. Lucro operacional bruto
2. Simples Nacional
3. **CBS a pagar** — `border-left: 3px solid brand`, valor em `brand`, sufixo "(reforma)" em 11px

> **Este é o ponto central da hierarquia:** um único número dominante, três de apoio. Não transforme os quatro em cards iguais.

### 3. Aba "Resultado" — a DRE
Cartão branco, `padding:28px 30px 22px`.

Cabeçalho: h2 "Demonstração de resultado" + subtítulo "Valores do mês e participação sobre a receita." À direita, botão **Ver detalhamento / Ocultar detalhamento** (12px/500, fundo branco, borda `line-2`, `padding:7px 13px`).

Estrutura de linhas, de cima para baixo:

| Linha | Divisória superior | Fundo | Cor |
|---|---|---|---|
| Receita declarada `PGDAS` · 100,0% | `1px solid ink` | — | ink |
| ( − ) Custo de vendas de produtos / outros | `1px solid line` | — | ink |
| **( = ) Lucro operacional bruto** | `1px solid line` | `brand-wash`, sangra 12px para fora | **brand** |
| **( − ) Despesas gerais e administrativas** | `1px solid line` | — | ink, 600 |
| ↳ *detalhamento das despesas (recolhível)* | | `surface-2` | |
| **( − ) Despesas tributárias** | `1px solid line` | — | ink, 600 |
| ↳ *detalhamento tributário (recolhível)* | | `surface-2` | |
| **( = ) Resultado líquido** | — | `ink`, texto branco, sangra 16px | branco |

Todo valor é seguido do percentual sobre a receita, em bloco de largura fixa `52px` alinhado à direita — é isso que mantém a coluna de percentuais alinhada.

**Detalhamento das despesas** (`surface-2`, `padding:6px 14px 10px`): grade de 5 colunas `minmax(0,1fr) 110px 62px 70px 92px`, `gap:10px`. Cabeçalho em Mono 10px caixa alta: Item · Valor · % base · Alíquota · Crédito CBS. Cada linha tem divisória superior `line`. **% base** e **Alíquota** são inputs; **Crédito CBS** é calculado, em `ink` quando > 0 e `disabled` quando zero. Rodapé com divisória `1px solid ink`: "Crédito de CBS gerado pelas despesas" + total.

**Detalhamento tributário:** lista simples nome → valor + percentual.

### 4. Aba "Reforma · CBS"
`grid-template-columns: minmax(0,1.15fr) minmax(0,1fr); gap:16px; align-items:start`

**Coluna esquerda — memória de cálculo.** h2 + subtítulo "Base × alíquota. Ajuste os campos e tudo recalcula."

*Bloco de premissas* (`surface-2`, `padding:14px 16px`, `margin-bottom:22px`, flex com quebra): à esquerda o rótulo "PREMISSAS" em Mono caixa alta + explicação "Alterar aqui vale para N de M linhas de despesa e para débitos e créditos."; à direita, dois campos de 78px, 15px/600 — **Alíquota geral** e **Medicamentos**. Alterar qualquer um propaga para todas as linhas creditáveis e para débitos/créditos de uma vez.

*Grade de cálculo* (4 colunas: `minmax(0,1fr) 118px 74px 104px`, `gap:10px`), em dois grupos com cabeçalho Mono 10px caixa alta e divisória `1px solid ink`:
- **Débito — receita tributada**: Medicamentos, Demais itens → subtotal "Débito total"
- **Crédito**: Crédito geral (despesas, somente leitura, vem da aba Resultado), Crédito medicamentos, Crédito estoque, Saldo credor do mês anterior → subtotal "Crédito total"

*Total:* faixa `brand`, texto branco, `padding:14px 16px`, sangrando 16px para fora — "CBS a pagar" + valor 19px Mono/600.

**Coluna direita — dois cartões de gráfico.**

*Débito, crédito e saldo* — três barras: Débito (`ink`), Crédito (`muted-3`), CBS a pagar (`brand`).

*Carga tributária — atual × transição* — número de variação grande em destaque (20px Mono/600; `brand` se aumentou, `ink` se diminuiu) seguido de "a mais que hoje" / "a menos que hoje", depois três barras:
1. Hoje — Simples Nacional integral (`ink`)
2. Simples sem a parcela da CBS (`muted-3`)
3. Na transição — Simples reduzido + CBS (`brand`)

Abaixo, separado por `1px solid line`, o campo **IBS a pagar (informe)** — premissa manual do usuário — e a nota "A memória calcula a CBS. O IBS é premissa sua — ao informar, a barra 'Na transição' se atualiza."

**Anatomia da barra:** rótulo 12px `ink-3` à esquerda + valor Mono 12px/500 à direita, `gap:5px`, depois trilho de 10px em `canvas` com preenchimento de 10px na cor da série. Largura = `valor / máximo da série × 100%`, com piso de 2% para que valores zerados continuem visíveis. `margin-bottom:14px` entre barras. Sem eixo, sem grade, sem legenda.

### 5. Aba "Resumo do cliente"
Cartão branco, `padding:40px 44px 36px`. h2 22px/600 `-0.02em` "O mês em quatro números" + subtítulo com `max-width:60ch`.

> **A faixa de indicadores muda nesta aba.** O bloco herói preto ("Resultado líquido do mês") é **ocultado** e o grid passa a uma coluna — `grid-template-columns` vira `minmax(0,1fr)`, com as três linhas (Lucro operacional bruto, Simples Nacional, CBS a pagar) ocupando a largura toda. Nas abas Resultado e Reforma o herói continua. Motivo: o valor já aparece nos cards logo abaixo; estava duplicado na mesma dobra.

**Quatro cartões:** `repeat(auto-fit, minmax(210px,1fr))`, `gap:1px`, cada um com `box-shadow: 0 0 0 1px #DAD8D2` (a borda vem da sombra, **não** de um fundo cinza no grid — isso evita células cinzas órfãs quando a última linha fica incompleta). Conteúdo: rótulo Mono caixa alta → valor 26px Mono/600 → nota 12px `muted`.
Receita · Resultado líquido · Simples Nacional · **CBS a pagar** (em `brand`)

**Duas colunas** `repeat(auto-fit, minmax(240px,1fr))`, `gap:28px`:
- **Para onde foi a receita** — quatro barras de 8px somando 100%: Custo de vendas (`ink`), Despesas gerais e administrativas (`ink-3`), Despesas tributárias (`muted-3`), Resultado líquido (`brand`)
- **O que observar** — parágrafo 13px `ink-3`, `line-height:1.65`, com os números interpolados do cálculo ao vivo (nunca texto fixo)

> ⚠ **Decisão pendente:** o protótipo mostra dois tratamentos lado a lado, marcados **A** e **B**, em dois lugares (composição da receita e cadeia de crédito). **Implemente apenas um de cada** e remova os rótulos A/B — eles são andaime de comparação, não parte do design. Os rótulos são um quadrado de 16px em `ink` (A) ou `brand` (B) com a letra em Mono 9px branca.
>
> - Composição da receita — **A**: as quatro barras de 8px. **B**: donut de 132px (`conic-gradient`, anel de 30px, furo branco) com a margem em 19px Mono/600 `brand` no centro e legenda à direita (quadrado 9px + rótulo + percentual Mono alinhado à direita).
> - Cadeia de crédito — **A**: barras por regime. **B**: pizza de 108px gera/não gera com legenda ao lado.

---

### 5.1 Cadeia de crédito (dentro do Resumo do cliente)
Bloco separado por `margin-top:36px; padding-top:28px; border-top:1px solid #E7E5E0`.

**Cabeçalho** — `space-between`, quebra em telas estreitas:
- Esquerda (`max-width:52ch`): h3 15px/600 "Cadeia de crédito" + parágrafo 13px `muted` que **responde à pergunta em vez de contar registros**: "3 dos 4 fornecedores geram crédito de CBS para a empresa. O regime tributário de cada um define o direito ao crédito."
- Direita: alternador **Fornecedores / Clientes** — trilho `#F2F1ED`, `padding:4px`, `gap:6px`; ativo: fundo branco + `box-shadow: 0 0 0 1px #DAD8D2`, texto `ink`; inativo: transparente, texto `muted`. Cada botão leva a contagem em Mono com `opacity:0.6`.

> Eram dois cartões de contagem lado a lado, um deles com borda preta grossa que parecia seleção acidental. São o mesmo conjunto de dados em dois estados — logo, um alternador, não dois cartões.

**Gráfico** (só quando há linhas) — mesmo vocabulário de "Para onde foi a receita": uma linha por regime, `max-width:520px`, `margin-bottom:10px` entre linhas. Rótulo 12px `ink-3` à esquerda, contagem Mono 12px à direita, trilho de 8px `canvas` abaixo. A barra pode ter **dois segmentos**: parte `ink` (gera crédito) e parte `brand` (não gera), ambas medidas sobre o **total geral de cadastros**, não sobre o grupo — é isso que mantém todas as linhas na mesma escala. Legenda embaixo (`margin-top:12px`, 11px `muted-2`), com quadrados de 9px; **cada item da legenda só aparece se existir pelo menos um cadastro daquela categoria**.

**Faixa de alerta** (só quando há CNPJ inválido) — `padding:10px 14px`, fundo `brand-wash`, `border-left:3px solid brand`. Título 13px/600 `brand` com plural correto ("1 CNPJ não confere" / "3 CNPJs não conferem") + explicação 12px `muted`: "Confira antes de usar o crédito na apuração."

> Antes a legenda ("Gera crédito: …") e o aviso de CNPJ estavam concatenados numa linha corrida só. São coisas diferentes: o aviso é um problema a resolver e sobe para uma faixa própria; a legenda é referência e desce para o rodapé da tabela.

**Tabela** — grid de 5 colunas `200px minmax(0,1fr) 170px 130px 28px`, `gap:12px`. Cabeçalho Mono 10px caixa alta com divisória `1px solid ink`; linhas com `padding:9px 0`, divisória `line` e `:hover { background:#FAF9F7 }`.

| Coluna | Tratamento |
|---|---|
| CNPJ | Mono 13px. Ponto de 5px antes do número: `line-2` quando válido, `brand` quando inválido; o próprio número fica em `brand` quando inválido |
| Nome | 13px `ink` |
| Regime tributário | 13px `muted` |
| Gera crédito | "Sim" em `ink`/400; "Não" em `brand`/600 |
| (ação) | Botão × de 22px, `#C7C5BF`, `:hover` `brand` sobre `brand-wash` |

> Três mudanças aqui: o ícone "!" em caixa saiu (o problema está no dado, então o dado fica vermelho); os quadradinhos verdes saíram (verde não existe na paleta) e só a **exceção** ganha peso — "Não" em vermelho e negrito, "Sim" neutro; o botão de remover tem alvo fixo em todas as linhas, em vez de aparecer só no hover.

**Rodapé da tabela** — `space-between`, `padding-top:12px`: botão de texto "+ adicionar fornecedor" (13px/500 `brand`, sublinha no hover) e a legenda 11px `muted-2` (`max-width:62ch`), que muda conforme a visão:
- Fornecedores: "Gera crédito: a compra deste fornecedor dá direito a crédito de CBS para a empresa."
- Clientes: "Gera crédito: a venda para este cliente permite que ele aproveite o crédito da CBS."

**Estado vazio** (lista sem itens) — `padding:38px 24px`, fundo `surface-2`, centralizado: título 14px/600, parágrafo 12px `muted` (`max-width:46ch`) explicando **por que vale cadastrar** — "Cadastrar os clientes mostra quanto da receita vai para quem aproveita o crédito da CBS — e quanto vai para consumidor final, que não aproveita." — e um botão sólido `ink` "+ adicionar cliente". Quando o estado vazio aparece, o subtítulo do cabeçalho **não** repete o mesmo texto: ele passa a explicar o conceito ("Quem vende e quem compra da empresa. O regime tributário de cada um define se há direito a crédito na reforma.").

**Concordância — obrigatória em todos os rótulos desta seção.** Três eixos combinam:
1. **Singular/plural por contagem:** `0 de 1 cliente aproveita` (nunca "dos 1 clientes aproveitam"); `1 de 2 gera crédito` (nunca "1 de 2 geram").
2. **Vocabulário por visão:** fornecedor *gera crédito* / cliente *aproveita o crédito*. Vale para o subtítulo, a legenda do gráfico, a nota de cada regime e o texto do botão de adicionar. Não misture os dois verbos na mesma tela.
3. **Caso "todos" e caso "nenhum":** "todos geram crédito" / "nenhum gera crédito" (e as versões de cliente), com o singular "gera crédito" quando o grupo tem um membro só.

### 6. Rodapé
Mono 11px `muted-2`, `space-between`: "Alexandre Araújo — Consultoria & Contabilidade" · "Valores em reais · competência dez/2025"

---

## Inputs — o padrão mais importante de acabamento

Nenhum campo tem caixa. Todo input editável é **texto alinhado à coluna**, indistinguível de um valor estático até a interação:

```
width: 100%;
text-align: right;
font-size: 13px;              /* 15px e weight 600 nos campos de premissa */
font-family: 'IBM Plex Mono';
padding: 2px 0;
border: none;
border-bottom: 1px solid transparent;
background: transparent;
color: #14161A;
outline: none;

:hover  { border-bottom-color: #C7C5BF; }
:focus  { border-bottom-color: #B3122B; }
```

(Nos campos de premissa e no IBS a borda inferior é `#C7C5BF` já em repouso, por serem controles principais.)

**Não** reintroduza caixas, fundos cinzas ou cantos arredondados nesses campos — foi uma correção explícita.

---

## Comportamento

**Recálculo ao vivo.** Toda edição recalcula tudo imediatamente, sem botão de aplicar. Não há debounce nem estado de carregamento.

**Parser numérico (pt-BR).** Aceita as duas convenções — obrigatório:
```js
function num(s) {
  if (typeof s === 'number') return s;
  let t = String(s).replace(/[^\d,.-]/g, '');
  t = t.indexOf(',') >= 0 ? t.replace(/\./g, '').replace(',', '.') : t;
  const v = parseFloat(t);
  return isNaN(v) ? 0 : v;
}
```
Se houver vírgula, ela é o decimal e os pontos são separadores de milhar. Sem vírgula, o ponto é decimal. Campo inválido vira 0 — nunca `NaN` na tela.

**Formatação.** Moeda: `'R$ ' + v.toLocaleString('pt-BR', {minimumFractionDigits:2, maximumFractionDigits:2})`. Percentual: `toLocaleString('pt-BR', {minimumFractionDigits:1, maximumFractionDigits:1}) + '%'`.

**Abas** — troca instantânea, sem transição. A faixa de indicadores e o cabeçalho permanecem.

**Detalhamento** — recolhível, aberto por padrão. Os dois blocos (despesas e tributárias) abrem e fecham juntos.

---

## Estado e fórmulas

### Estado
```
tab            'resultado' | 'reforma' | 'cliente'
detalhe        boolean (padrão true)
despesas       [{ nome, valor: number, base: string, aliq: string }]
debitos        [{ nome, base: string, aliq: string }]
creditos       [{ nome, base: string, aliq: string }]
saldoAnterior  string   ('0,00')
ibs            string   ('0,00')
aliqGeral      string   ('8,00%')
aliqMed        string   ('3,20%')
cadeia         'fornecedores' | 'clientes'
fornecedores   [{ cnpj, nome, regime, credito: bool, cnpjOk: bool }]
clientes       [] (mesma forma)
```
Valores editáveis são **strings** (preservam o que o usuário digitou); a conversão acontece no cálculo.

### Constantes
```
receita       106419.89   (declarada no PGDAS)
custos         58039.60
simples         4889.93   (Simples Nacional integral)
simplesSemCbs   4140.30   (Simples sem a parcela da CBS)
tributarias   [Simples Nacional 4889.93, INSS 986.67, FGTS 987.19, SEFAZ 678.16]
```

### Despesas (valor, % base, alíquota)
```
Retirada de sócio                        0.00    0%   0%
HapVida                                804.29    0%   0%
Folha                                12346.56    0%   0%
Aluguel                               2700.00   30%   8%
Seguro                                 125.87  100%   8%
Telefone / Internet                    151.26  100%   8%
Energia / Cagece                      1946.13  100%   8%
Contabilidade                         2100.00   70%   8%
Corpvs Segurança                       152.84  100%   8%
Taxa de banco e cartões               2537.14  100%   8%
Sistema                                800.00  100%   8%
Manutenção, dedetização, equipamentos     5.00  100%   8%
Outras despesas                        181.00    0%   0%
```

### Débitos e créditos de CBS
```
Débito  Medicamentos          base 103685.52   aliq 3,20%
Débito  Demais itens          base   2734.37   aliq 8,00%
Crédito Crédito medicamentos  base  60372.13   aliq 3,20%
Crédito Crédito estoque       base   1867.18   aliq 8,00%
```

### Cadeia de crédito — dados iniciais
```
06.862.627/0001-38  teste     Simples Nacional   gera crédito   CNPJ ok
06.862.627/0001-30  teste 01  Lucro Real         gera crédito   CNPJ inválido
06.862.627/0001-31  teste 03  Lucro Presumido    gera crédito   CNPJ inválido
06.862.627/0001-36  teste 04  Simples Nacional   não gera       CNPJ inválido
clientes: vazio
```
São dados de teste — substitua pelos reais. A validação de CNPJ está apenas sinalizada (`cnpjOk`), **não implementada**: implemente o cálculo dos dígitos verificadores.

Agrupamento por regime na ordem fixa Simples Nacional → Lucro Presumido → Lucro Real; regimes fora dessa lista entram depois, na ordem em que aparecem. Regimes sem nenhum cadastro não são exibidos.

### Fórmulas
```
despTotal     = Σ despesas.valor
tribTotal     = Σ tributarias.valor
lucroBruto    = receita − custos
resultado     = lucroBruto − despTotal − tribTotal
margem        = resultado / receita × 100

créditoLinha  = valor × (base/100) × (aliq/100)
creditoGeral  = Σ créditoLinha
baseDespesas  = Σ (aliq > 0 ? valor × base/100 : 0)

debitoTotal   = Σ (base × aliq / 100)          sobre debitos
creditoTotal  = Σ (base × aliq / 100) sobre creditos + creditoGeral + saldoAnterior
cbsPagar      = max(0, debitoTotal − creditoTotal)

naTransicao   = simplesSemCbs + cbsPagar + ibs
delta         = naTransicao − simples
```

**`cbsPagar` nunca é negativo** — excedente de crédito vira saldo credor, não devolução. O piso em zero é obrigatório.

### Propagação das premissas
Alterar **Alíquota geral** → grava em toda linha de despesa cuja alíquota atual seja > 0 (linhas com alíquota 0 permanecem sem crédito), no débito "Demais itens" e no "Crédito estoque".
Alterar **Medicamentos** → grava no débito "Medicamentos" e no "Crédito medicamentos".

### Valores esperados com os dados iniciais
```
lucroBruto    R$  48.380,29   (45,5%)
despTotal     R$  23.850,09   (22,4%)
tribTotal     R$   7.541,95   ( 7,1%)
resultado     R$  16.988,25   (16,0%)
creditoGeral  R$     639,86
debitoTotal   R$   3.536,69
creditoTotal  R$   2.721,14
cbsPagar      R$     815,55
naTransicao   R$   4.955,85   → R$ 65,92 (1,3%) a mais que hoje
```
Use esta tabela como teste de regressão da sua implementação.

---

## Responsividade
Layout fluido, sem largura fixa. As duas grades de duas colunas (faixa de indicadores e aba Reforma) usam `minmax(0, …fr)` e devem virar uma coluna abaixo de ~900px. Os cartões do resumo já usam `auto-fit / minmax(210px,1fr)`. O cabeçalho quebra com `flex-wrap`. As grades de detalhamento (5 e 4 colunas) são o ponto de tensão em telas estreitas — role horizontalmente ou reorganize em pares rótulo/valor.

## Acessibilidade
- Todo input precisa de `<label>` associado (as premissas já usam `<label>`; as células de tabela dependem do cabeçalho da coluna — adicione `aria-label` por linha, ex. "Aluguel — % base")
- Abas devem virar `role="tablist"` / `role="tab"` com `aria-selected` e navegação por setas
- Barras são decorativas em relação ao número que já está escrito ao lado: `aria-hidden="true"`
- Contraste: `muted-2 #8A8D94` sobre branco fica em 3,5:1 — aceitável em 12px apenas para percentuais redundantes; não use para texto essencial

## Assets
Nenhum. O "logo" é o quadrado vermelho com a letra A — **substitua pelo logo real do escritório**. Fontes vêm do Google Fonts (IBM Plex Sans + IBM Plex Mono); no seu projeto, sirva-as localmente ou use o equivalente do seu design system.

## Arquivos deste pacote
- `Painel DRE.dc.html` — o protótipo completo (referência visual e de comportamento)
- `README.md` — este documento

## Pendências não implementadas
Levantadas na conversa, ainda em aberto:
1. Comparativo mês a mês (exige série histórica)
2. Decomposição do delta de carga: quanto vem de débito, de crédito perdido, do IBS
3. Redundância entre as abas Resultado e Reforma (as mesmas despesas aparecem nas duas)
4. Exportação do "Resumo do cliente" como PDF de uma página
5. Escolher entre A e B nos dois gráficos e remover o perdedor (ver seção 5)
6. Ponderar a cadeia de crédito por **valor de compra** por fornecedor, não por número de cadastros — hoje o gráfico conta cabeças, e o que decide o crédito é quanto se compra de cada um
7. Validação real de CNPJ (dígitos verificadores)
