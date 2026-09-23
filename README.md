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
  gerar_dashboard.py       # injeta logo e fontes; com .env, gera também build/DRE_Dashboard_banco.html
  dashboard_template.html  # dashboard completo (1 arquivo, sem dependências externas)
supabase/
  migrations/20260911120000_estrutura_inicial.sql   # tabelas, segurança (RLS) e funções de salvar/carregar
  migrations/20260916130000_protecao_dos_dados.sql  # lixeira, versões e trava das listas da empresa
  scripts/adicionar_membro.sql                       # dar acesso a alguém da equipe
  scripts/conferir_instalacao.sql                    # conferir se o banco ficou configurado
scripts/
  vercel_build.mjs         # build da Vercel: publica só o painel, ligado ao Supabase pelas variáveis
vercel.json                # manda a Vercel rodar o build acima e publicar a pasta public/
.env.example               # modelo das variáveis do Supabase (copie para .env, que não vai para o git)
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
`#E3E2DD`, IBM Plex Sans na interface e IBM Plex Mono em todos os números. Cantos retos,
sem sombras. Tema claro por padrão e **modo noturno** opcional (ver "Modo noturno" abaixo).

**Fundo e cartões em três níveis** (16/09/2026): página `#E3E2DD`, cartão branco e, dentro dele, cartão
em `--surface-2` com faixas brancas (hoje no quadro Tradicional × Híbrido). O fundo era `#EFEEEA` e, sem
sombra, cartão branco e página quase não se separavam. A barra das abas (`--rail`) desceu junto para
`#DAD8D2`, porque o fundo novo tem o tom que ela tinha e ela sumiria. Escolhido entre quatro versões
renderizadas lado a lado.

**Cuidado:** as cores personalizáveis são `--fill` (preenchimentos: aba
ativa, barra do débito, faixa do resultado) e `--brand`. O texto usa `--ink`, que nunca
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

## Layout v2 (19/09/2026)

Redesenho da casca, a partir do handoff em `design_handoff_painel_dre_v2/` (protótipos em HTML; nenhum
cálculo mudou). O que entrou:

- **Barra lateral** (`rLateral`, 244px, `.lat`): logo e nome do escritório, a empresa aberta (o cartão **é** o
  seletor — o `<select>` fica invisível por cima), navegação em dois grupos (Mês · <competência> com Visão geral,
  Resultado, Comparar regimes e Resumo do cliente; Exercício com Anual) e, no pé, o estado do salvamento com
  Baixar PDF e Opções. Recolhe para 64px (`ui.latFina`, só os pontos, nome no `title`) e, abaixo de 900px, vira
  gaveta com véu (`ui.latAberta`, botão ☰ no cabeçalho). **Na apresentação ela recolhe sozinha**: a lista de
  empresas é de outros clientes.
- **Cabeçalho preso no alto** (`rCabecalho`): empresa, CNPJ · competência, alternador **Lançar / Apresentar**
  (o mesmo que o item do menu: recolhe a maquinaria ao entrar e devolve ao sair), seletor de competência,
  Tela cheia (só apresentando) e Salvar. A barra compacta que descia ao rolar saiu — o cabeçalho já é fixo.
- **Cinco seções** no lugar de três: a **Visão geral** é nova; o quadro Tradicional × Híbrido ganhou seção
  própria (**Comparar regimes**); a DRE, o estoque e a memória ficaram no **Resultado**. Os ids `#tab-<id>`
  continuam os mesmos.
- **Visão geral**: três indicadores do mês (imposto, CBS a pagar, resultado líquido, com a variação contra o
  mês anterior), o gráfico **receita e imposto mês a mês** (`rMeses`: barra = receita do mês, pedaço de baixo =
  imposto; mês sem competência salva vira faixa hachurada) e a faixa do Simples (RBT12, faixa, anexo). Ela vive
  dos meses salvos, então entrar nela carrega o ano (`garantirAnoDaTela`), e salvar um mês pede os números de novo.
- **Fator R** (19/09/2026, `garantirFatorR`/`carregarFatorR`/`calcFatorR`/`rFatorR`, na Visão geral): a linha dos
  faturamento e da folha mês a mês com a linha do Fator R e o corte de 28% por cima, mais a leitura em português
  do que isso muda no anexo. **Só aparece para a empresa marcada** em Opções → *Acompanhar o Fator R*: é decisão do escritório
  sobre o cliente, não do mês, então a marca fica na empresa (coluna `empresas.fator_r`, migração
  `20260923120000`). Sem a migração o painel não quebra — a marca passa a valer só no navegador de quem ligou
  (`localStorage`, chave `dre.fatorR`) e o aviso aparece no próprio toast.
  - **De onde vêm os números:** duas consultas. `rpc/resumos` no intervalo (a função já devolve a receita do
    resumo ou, no mês antigo sem resumo, do próprio estado salvo — por isso o mês só precisa estar **salvo**) e
    `competencias?select=periodo,ga:dados->monthly->ga` para a folha, somada por `categoriaFolha` (salário e
    pró-labore). São buscados **23 meses**, não 12: cada ponto do gráfico é a janela de doze que termina nele, e
    doze pontos pedem 23 meses de histórico (`FATOR_R_MESES`, `janelaMeses(ate, n)`).
  - **Encargos:** entram por um percentual à parte (`presumido.fatorEncargos`, padrão 8% — o FGTS), editável no
    próprio cartão. O painel mostra a conta aberta em vez de decidir sozinho o que é folha.
  - **Ponto vazio:** a janela com menos de três meses salvos não vira ponto. A linha começa onde o histórico
    começa, em vez de desenhar uma queda que é só falta de lançamento.
  - **O gráfico** (23/09/2026) é **um quadro só**, no formato que o escritório pediu: faturamento e folha em
    barras lado a lado por mês, a linha do Fator R por cima, reais à esquerda, porcentagem à direita e o limite
    de 28% tracejado. A primeira versão separava a linha num painel embaixo (um eixo por unidade, como manda a
    cartilha de visualização); o usuário comparou as duas na tela e escolheu esta.
    - **Séries ligáveis:** a legenda liga e desliga faturamento, folha e linha (`ui.frrFat`, `ui.frrFolha`,
      `ui.frrLinha`); a última acesa não apaga, porque quadro vazio não diz nada. Desligando as barras sobra a
      linha sozinha, e o eixo de reais some junto.
    - **12 ou 6 meses** (`ui.frrJanela`): a vista encurta, o Fator R continua sendo o dos doze meses móveis —
      é a definição da LC 123, não uma média do que está na tela.
    - **Rótulo só onde cabe:** com doze meses, o valor em reais aparece na maior barra de faturamento e na do
      mês aberto; com seis meses, em todas as barras. O `title` da coluna abre a conta inteira — faturamento,
      folha considerada e, embaixo, salários + pró-labore + o percentual de encargos —, que é a pergunta que
      mais apareceu ("de onde saiu esse valor de folha?"). A legenda também traz a composição em cinza.
    - **Escalas redondas:** `escalaReais()` sobe o topo até um número redondo com quatro divisões; a régua de
      porcentagem usa o menor passo de 5, 10, 15, 20, 25 ou 50 pontos que caiba o intervalo **com os 28% dentro**.
    - **Cores:** verde `#86CCA8` (faturamento), azul `#4C7FB8` (folha), verde escuro `#1B6B55` (linha) e
      `#C2565A` (limite), com tons próprios no modo noturno (`--frr-fat`, `--frr-folha`, `--frr-linha`,
      `--frr-limite`). Três cortes foram comparados na tela; este é o escolhido. O azul é **de propósito** mais
      fechado que o verde: com os dois igualmente claros, o `validate_palette.js` acusou ΔE 5 no daltonismo
      tritan (indistinguíveis) — assim são 20. A família do painel (rosa do gráfico de receita + terroso da
      cadeia, linha em grafite) também foi montada e comparada, e foi recusada.
    - **A linha** é fina (1,6px): vai reta de um mês ao outro e só arredonda os vértices (`curvaSuave()` corta
      22% de cada segmento no canto e refaz com uma quadrática que passa pelo próprio ponto, então nenhum valor
      é deslocado). Duas versões anteriores foram recusadas: a polilinha de 2px com pontos de 6px ("grosseira")
      e a Catmull-Rom cheia, que ondulava demais. Por baixo vai um halo da cor do cartão (4px na linha, 6,5px
      nos pontos), senão ela some dentro das barras.
    - **A porcentagem aparece em todos os pontos**, com um contorno da cor do cartão (`text-shadow` repetido)
      para não precisar de caixa nem fundo em cima das barras; a do mês aberto vai num selo cheio.
    - **Barras em HTML, linha em SVG** por cima, os dois na mesma caixa: o canto arredondado, a hachura do mês
      sem competência e o `title` por coluna saem de graça, e a linha aproveita o `viewBox` de 0–100 com
      `vector-effect:non-scaling-stroke` (o ponto é um traço de comprimento zero com ponta redonda; um `<circle>`
      viraria elipse com `preserveAspectRatio="none"`).
  - Entra também como item do **selo** (âmbar abaixo dos 28% ou a menos de 2 pontos do corte) e como termo do
    glossário. Como o selo aparece em todas as abas, o Fator R é buscado junto com o ano.
- **Selo de conferência** (`conferencias`, `rSelo`): faixa acima do conteúdo, verde quando tudo passa e âmbar
  quando algo pede atenção, expansível item a item. As verificações são as que o painel prova sozinho: receita da
  DRE × soma das linhas do PGDAS, DAS declarado × calculado, crédito de CBS compatível com as compras, CNPJ dos
  cadastros, Fator R com folga para o Anexo III e — com banco — exercício completo.
- **Glossário** (`TERMOS`, `rGlossario`): botão "?" ao lado dos termos (DAS, CBS, alíquota efetiva, RBT12) abre
  um painel no canto com a explicação em português de quem não é da área (DAS, CBS, regime híbrido, alíquota
  efetiva, RBT12, crédito de CBS e Fator R).
- **"Como ler"** no pé da DRE, só na apresentação: de cada R$ 100 de receita, quanto foi para imposto e quanto
  sobrou, mais a CBS do mês.
- **Paleta e tipografia do handoff**: fundo `#E9E7E2`, filetes `#EFECE6`/`#E2DFD8`, texto `#16171A`/`#4A4D52`,
  cantos de 9px (14px nos cartões) e **Instrument Sans** na interface, embutida em base64 como as outras — o
  painel continua sendo um arquivo só, sem buscar nada na rede.
- Ficou para depois: as telas de **Comparar regimes** e **Anual** ainda usam o desenho antigo dentro da casca
  nova, e a DRE no modo Lançar mantém os campos como estão.

- **Cabeçalho em duas linhas** (17/09/2026): em cima, uma faixa só do escritório — logo pequena e nome em
  maiúsculas finas, fechada por um filete; embaixo, a empresa do cliente em destaque e a linha de contexto
  (`DRE · Dezembro 2025 · CNPJ 00.000.000/0001-00` — o CNPJ vem do banco e antes só saía na impressão).
  Antes a logo ficava colada ao nome da empresa e parecia ser do cliente. A outra forma testada — escritório
  e cliente lado a lado, com um traço no meio — foi recusada. Sem rótulo "preparado por": a faixa já diz quem
  assina. As abas ficam à direita, na altura do nome do cliente (em tela estreita voltam para baixo dele)
- **Faixa de indicadores** fixa nas abas do mês, sem bloco herói (o resultado líquido já fecha a DRE e está
  nos cartões do resumo): Simples Nacional e CBS a pagar no mês. A aba Anual não tem faixa
- **Acabamento visual** (18/09/2026): quatro mudanças de sistema, todas de aparência — nenhuma conta mudou.
  Vieram de uma conversa sobre o painel estar "chapado demais":
  - **Escala de espaço** em tokens (`--e1:4px … --e7:48px`): todo recuo e toda distância saem dela. Antes cada
    bloco tinha o seu compasso (cartão `28/30/22`, painel `22/26`, faixa `12/18`, barra `12/16`), e era isso que
    fazia a página parecer desalinhada. O espaço entre cartões subiu para 32px e o recuo interno caiu para 24px:
    os blocos se separam melhor e o miolo fica mais junto.
  - **Filete e sombra no cartão:** `.card` era branco sobre bege sem borda nenhuma, enquanto `.kc`, `.barra` e
    `.login` já tinham filete. Agora todos têm 1px, mais uma sombra de papel (contato bem fraco + sombra larga e
    quase invisível embaixo). Comparada na tela com a versão só de filete, esta ganhou. No modo noturno fica só o
    filete (sombra em fundo escuro suja em vez de dar volume) e no papel não sai nenhum dos dois.
  - **A linha acende ao passar o mouse** (`.dl`, `.hero-row`, `.sn-l`, `.gano`, `.gpres`, `.gr`, `.cr`): o fundo
    avança 12px para os lados com duas sombras sem borrão, para respirar sobre o recuo do cartão sem empurrar nada
    e sem invadir a linha de cima nem a de baixo. Fica de fora o resultado líquido, que já tem fundo próprio.
  - **Negrito só no que decide:** os rótulos desceram para 500 e o peso 600 ficou nos números — receita, totais,
    resultado, cartão vencedor. Antes quase toda linha era 600 dos dois lados.
  - **O número conta até chegar, só na apresentação** (`contarAte()`, `CONTA_SEL`): os valores de destaque (faixa
    de indicadores, cartões do resumo, receita, lucro bruto, totais, resultado, os dois regimes) sobem até o valor
    em 420ms, com desaceleração. Fora da apresentação o número entra pronto — quem digita quer ver na hora.
    Dois cuidados que custaram teste: o carimbo do primeiro quadro pode ser **anterior** ao início da conta (sem
    piso em 0 a curva dispara e o número aparece em outra casa), e um `setTimeout` de segurança crava o valor
    final caso o navegador pare de dar quadros (aba escondida).
  - **A barra se revela ao aparecer** (`@keyframes revela`): quando um bloco entra, a faixa é descoberta da
    esquerda para a direita por `clip-path`, e não por cada pedaço esticando — assim as partes empilhadas
    (débito, crédito, composição dos tributos) não se desencontram. O atraso segue o do bloco (`--i` herda do
    pai). Quando só o valor muda, a largura desliza em 300ms. No papel, barra cheia e sem animação.
  - **Luz no cartão:** no claro a base escurece um fio (`--card-luz`, 3% do bege por cima do branco); no escuro é
    o alto que clareia. É papel sob luz que vem de cima — não se vê, se sente. No papel o cartão volta a ser chapado.
  - **A troca de tema cruza em 220ms** em vez de cortar seco: `aplicarTema()` liga a classe `tema-trocando`, que
    vale uma transição universal (fundo, texto, borda, sombra) só durante o cruzamento, e a desliga em 260ms. O tema
    em si muda na hora, por baixo dela — quem lê o estado logo depois vê o valor novo, só a cor chega andando.
  - **A apresentação abre em vez de saltar:** o conteúdo entra com um fade de 260ms (`abrePresent`). O `zoom:1.15`
    continua imediato de propósito — animá-lo borra o texto no meio do caminho.
  - **Cantos de 4px em tudo** (`--r`, e `--r-2:3px` para o que fica dentro de um trilho, como as abas): antes o
    painel falava duas línguas — cartões e tabelas retos, controles com 2px. Comparadas na tela a versão toda reta
    e a de 4px, ganhou a de 4px. O recorte da faixa de indicadores fica no contêiner (`overflow:hidden`), senão o
    fundo que faz as divisórias sobra nas quinas. No papel tudo volta a ser reto.
  - **Dígitos de largura fixa** (`font-variant-numeric:tabular-nums` no `body`): em mono os números já alinhavam,
    em Sans (percentuais, variações, valores dentro de frases) não.
  - **Esqueleto no lugar da barra de carregamento** (`body.trocando`): enquanto o mês chega do banco, os rótulos
    ficam e só os números viram barras cinza, do tamanho que tinham (texto transparente + gradiente que corre).
    Antes a tela inteira esmaecia e uma barra vermelha corria no topo — parecia erro e escondia o que nem ia mudar.
    O elemento `#progresso` e o CSS dele saíram.
  - **Estado vazio não é aviso** (`.vazio`): ausência de conteúdo passa a ser um traço, um título e uma frase no
    espaço que o conteúdo ocuparia — aba Anual sem banco, ano sem competências salvas, banco sem a função
    `resumos`, e os cadastros de fornecedores, clientes e produtos (que perderam o fundo cinza). A caixa `.flag`
    ficou só para o que é aviso de verdade (ICMS não informado, meses faltando, DAS sem tabela).
  - **Quatro tons de texto no lugar de sete:** `--ink-2`/`--ink-3` passaram a ser o mesmo tom, e `--muted-2`/
    `--muted-3` também (nos dois temas). Os nomes ficaram — são centenas de usos —, o que saiu foi a variedade:
    sete cinzas liam como descuido, não como hierarquia.
- **Abas:** Resultado · Resumo do cliente (mês) · Anual; setas do teclado navegam. A aba Resultado vai da
  DRE à apuração: Simples Nacional do mês → DRE → Estoque e compras → memória de cálculo da CBS
- **Impressão e PDF** (16/09/2026), em Opções → "Imprimir / PDF…":
  - **A janela pergunta o que sai no papel:** "Só os totais" ou "Com o detalhamento" (linhas de receita e
    despesas, compras, estoque e memória da CBS; na aba do cliente, as tabelas de cadastro; na Anual, as linhas
    do exercício). O padrão acompanha a tela. As seções abrem ou fecham **só durante a impressão** — um
    `afterprint` devolve a tela como estava. Ctrl+P imprime a tela do jeito que está, com a mesma folha.
  - **Folha A4** (`@page`, margens 14/12/16 mm). Antes saía em Carta e sem margem definida.
  - **Rodapé em toda página** — escritório à esquerda, "Página x de y" à direita — e, da 2ª página em diante,
    empresa e período no alto. São caixas de margem do `@page` (Chrome 131+), montadas em `prepararFolha()`
    no `beforeprint`, porque o texto muda com a empresa. As caixas vazias não são enfeite: cada borda com caixa
    definida cala a data, o título e o endereço que o Chrome põe quando "Cabeçalhos e rodapés" está ligado.
    O rodapé da tela (`footer.foot`) sai do papel: sozinho no fim, chegava a ocupar uma folha inteira.
  - **Cabeçalho:** "valores em reais" e data e hora de emissão (o CNPJ está na linha de contexto, que
    também sai no papel).
  - **Nome do PDF:** o título da página vira "Empresa — DRE dez-2025" durante a impressão (o Chrome usa o
    título como nome do arquivo); caracteres proibidos em nome de arquivo viram hífen ("S/A" → "S-A").
  - **Quebra de página:** cartão grande pode quebrar (com `break-inside:avoid` inteiro ele pulava para a folha
    seguinte e deixava meia folha em branco); linha, gráfico, memória fechada e o quadro dos regimes não
    quebram; título fica com o que vem embaixo. Os blocos viram fluxo comum (`display:block`) porque é nele
    que o Chrome respeita essas regras. Resultado com totais: de 4 folhas para 2; com tudo aberto, de 7 para 4.
  - **Largura:** no papel o cartão perde o recuo (fica 16px, o bastante para as faixas coloridas avançarem —
    o que passa da área útil o Chrome corta, e o texto encostava na borda da faixa). Tabelas ganham colunas
    próprias para caber em A4 (produtos tinha `min-width:880px` e cortava), sem a coluna do botão de remover.
    Memória fechada fica ao lado do gráfico e os dois regimes lado a lado, como na tela larga.
  - **Nada de tela no papel:** botões, links, "+ adicionar", alternador fornecedores/clientes, setas e traços de
    campo, texto de exemplo e instruções ("Abra a memória para ver…") somem. Texto só de tela leva `.so-tela`;
    texto só do papel, `.so-papel`.
  - **Nome comprido não corta:** campo de texto não quebra linha ("Manutenção, dedetização, equ").
    `nomesNoPapel()` põe uma cópia em texto comum ao lado de cada campo durante a impressão e tira depois.
  - Testes (seção 14 do painel; CNPJ na seção 3 do banco): janela e padrão, abre e devolve a tela, cancelar,
    caixas de margem, título do PDF, emissão, cópias dos nomes. A aparência foi conferida gerando o PDF no
    Chrome headless (`--print-to-pdf`) e olhando página a página.
- **Modo noturno** (16/09/2026), em Opções → "Modo noturno" (marca *ligado*):
  - **Só os tokens trocam** (`html[data-tema="escuro"]`): fundo `#111214`, cartão `#1B1C1F`, cartão interno
    `#232529`, texto `#ECEDEF`. `color-scheme:dark` deixa as listas de seleção e a rolagem nativas escuras.
  - **`--fill` e `--brand` são recalculadas em `refresh()`**: são as cores personalizáveis, chegam como estilo
    inline e estilo inline vence qualquer regra do CSS. No escuro o vermelho da reforma clareia 30% (vira texto
    em fundo escuro) e um `--fill` escuro vira `#E4E5E8` — senão aba ativa, Salvar e faixa da decisão sumiriam.
  - **`--sobre-fill`** substituiu o `#fff` cravado no texto sobre `--fill`, escolhido pela luminância da cor
    (`luz()`). De quebra conserta o claro: cor personalizada clara (amarelo) ganhava texto branco ilegível.
  - A **logo** ganha uma placa branca no escuro (ela é escura). A faixa verde do híbrido fixa texto branco.
  - **Preferência de quem olha, não dado da empresa:** fica no navegador (`localStorage` `dre.tema`), não no
    estado salvo. Um script no `<head>` aplica o tema antes de desenhar, para a página não piscar clara.
  - **Imprimir sai sempre no claro** (`beforeprint`/`afterprint`) e volta ao escuro depois.
  - Cores dos gráficos seguem os tokens. As faixas de redução da CBS têm rampa própria (`--cbs-0…--cbs-6`),
    com passos mais cheios no escuro, porque sobre fundo escuro a mistura com branco clareia rápido demais.
  - Testes (seção 13): ligar pelo menu, tokens e cores recalculadas, cor clara personalizada, impressão no
    claro e volta, desligar esquece; 13b abre já escuro quando lembrado. O perfil do Chrome de teste guarda o
    `localStorage` entre execuções: os testes limpam `dre.tema` no fim, senão contaminariam as suítes seguintes.
- **Movimento** (16/09/2026), para a navegação não parecer seca:
  - **Botões e abas** mudam de cor em 150ms ao passar o mouse e **afundam 1px** enquanto pressionados; aba
    não selecionada clareia no hover (antes não tinha efeito nenhum).
  - **Só o que é novo entra com efeito** (sobe 6px e aparece, 240ms). O cuidado é que `render()` refaz a
    tela inteira: animar tudo faria a página piscar a cada linha adicionada. `chavesNaTela()` anota o que
    existia antes, e `animarNovos()` marca `.entra` só no que não existia — a aba nova (blocos em cascata de
    35ms), a seção que abriu, o menu, a linha recém-criada. Linha e seção se reconhecem pelo primeiro
    `data-b` (ou botão) que carregam; dentro de um bloco que já entra, o filho não anima de novo.
  - **Troca de mês ou de empresa** (`trocar()` → `ocupado()`): o conteúdo esmaece e trava, uma barra
    corre no topo enquanto o banco responde, e o mês novo entra por inteiro — cabeçalho e barra de seleção
    ficam parados. Antes a tela congelava e parecia que o clique não tinha pegado.
  - **Janelas** (salvar antes de trocar, novo mês, senha) aparecem com o fundo esmaecendo e a caixa subindo.
  - Preenchimento `backwards`, não `both`: terminado o efeito, vale o estilo normal. Com `both` a opacidade
    ficaria presa em 1 e o esmaecido da troca de mês não funcionaria mais nos blocos já animados.
  - **Barra compacta ao rolar** (`rFixo()`, `marcarRolagem()`): quando a barra de seleção sai da tela, desce
    uma barra fina com nome e competência, as abas e — com banco — o status e o Salvar. A aba Resultado é
    longa e, para salvar ou trocar de aba lá do fim, era preciso rolar tudo de volta. Clicar no nome sobe
    suave até o topo (para trocar empresa ou mês); trocar de aba por ela já começa a aba nova do topo. O
    nome e a competência reaproveitam `data-o="co"`/`"ctx"`; o status é cópia **sem `aria-live`**, senão o
    leitor de tela anunciaria cada salvamento duas vezes. `scroll-padding-top` evita campo focado escondido
    atrás dela. No celular as abas encurtam como as principais ("Resumo") e, até 480px, o nome sai e as
    três dividem a largura — antes disso a aba Anual ficava escondida numa rolagem lateral invisível.
    Na apresentação as abas continuam, o Salvar não.
  - **`prefers-reduced-motion`** desliga tudo (`animation:none; transition:none`): quem pediu ao sistema menos
    movimento não recebe efeito. No Windows é "Mostrar animações no Windows" — desligado, o painel fica sem os
    efeitos. A primeira versão encurtava tudo para 1ms, o que dava transição de 1ms a *toda* propriedade de *todo*
    elemento, inclusive a cor ao trocar de tema. Sem movimento, a barra de carregamento fica cheia e parada.
  - **Nota para quem testa:** com `--virtual-time-budget` o Chrome sem janela adianta os timers sem desenhar
    quadros, então um bloco que acabou de entrar aparece apagado (animação parada no início). Não acontece para
    o usuário: medido em tempo real (página segurada por uma imagem lenta), a seção termina em opacidade 1 em
    menos de um segundo. Capturas de tela usam `--force-prefers-reduced-motion`.
  - Testes (seção 11): redesenhar sem mudança não anima nada; adicionar despesa anima só a linha nova;
    remover não anima o resto; abrir o menu anima só o menu; troca de mês deixa topo e barra parados.
    Seção 12: a barra compacta fica escondida no topo, aparece ao rolar com a aba certa, troca de aba e
    volta ao topo, sobrevive a um render lá embaixo; no teste com banco, o status repetido sem `aria-live`.
  - **Nota para quem testa:** o Chrome sem janela no Windows não desce de 484px de largura nem fotografa a
    página rolada. As conferências de celular (360px) e da barra compacta foram feitas com a página dentro
    de um iframe.
- **Detalhamento** recolhível e **fechado por padrão** (receita por tipo, despesas com regra de
  crédito/alíquota/crédito e tributárias); "Estoque e compras" tem o seu próprio botão, também fechado
- **Despesas editáveis no detalhamento:** nome e valor de cada despesa são campos (sem precisar de
  "Editar valores"), com "+ adicionar despesa" e × para remover. A despesa nova entra com crédito
  integral pela alíquota geral
- **DAS não digitado: a DRE usa o calculado** (`dasNaDre`, 13/09/2026). Enquanto a linha "Simples Nacional"
  estiver zerada e houver anexo e receita dos 12 meses, ela mostra o **DAS que sai da receita por tipo**,
  com "*calculado · digitar*" embaixo, e esse valor entra nas despesas tributárias, no resultado e na
  margem. Antes o quadro "Tradicional × Híbrido" já usava o DAS calculado e a DRE contava zero — o lucro
  do mês aparecia maior do que é. O link **digitar** passa o valor para o campo (vira declarado, editável).
  Nada é gravado sozinho; quem digita, manda. Os dois formatos ficam no DOM e o `data-v` escolhe, porque
  digitar a receita só dá `refresh()`. **Sem a linha do Simples** na lista não há onde mostrar o valor, e
  aí ele fica fora do total da DRE (o cálculo da comparação continua usando o DAS calculado).
  A conferência com o PGDAS segue olhando o **declarado** (`simplesDeclarado`), senão a diferença seria
  sempre zero
- **Regra de crédito por despesa e por compra** (no lugar do "% base"): Integral, Redução de 30%
  (profissões regulamentadas: contabilidade, advocacia), **Redução de 40%**, Redução de 50%,
  Redução de 60%, Redução de 70% (aluguel), Sem crédito e
  "Outra parte…" (janela para digitar o %). Por baixo continua a parte da base (`ga[i][2]`):
  "Sem crédito" zera a alíquota; passar a ter crédito entra pela alíquota geral
- **Alíquota efetiva embaixo da cheia** (despesas e compras): quando a regra reduz a base, o que de fato
  incide é menor — 30% da base × 8% = "*efetiva 2,40%*", em cinza sob o campo da alíquota. Vale também na
  linha ainda zerada: é a taxa que valerá quando ela receber valor. Fica de fora só quando não há o que
  mostrar — sem redução a efetiva é a própria alíquota, e com alíquota zerada não há crédito nenhum.
  O espaço da segunda linha fica reservado em toda linha, para a tabela manter um ritmo só
- **Memória de cálculo da CBS** recolhível ("Ocultar memória"): fechada, mostra só débito total,
  crédito total e a faixa da CBS; aberta, as premissas e linha a linha
- **CBS Crédito:** quando o crédito passa do débito, a CBS aparece em verde (`--ok #1D7A4E`) como
  "CBS Crédito", com o saldo que vai para o mês seguinte — na faixa da memória, no indicador do topo,
  no Resumo do cliente e no gráfico de débito e crédito. Nunca aparece CBS a pagar negativa
- **Estoque e compras** (aba Resultado): o total das compras do mês em cima e, no detalhamento, a
  **tabela de compras com as mesmas colunas das despesas gerais** (Item, Valor, Regra de crédito,
  Alíquota, Crédito CBS), com adicionar e remover; abaixo, "Posição de estoque e pagamentos"
  (inventário, estoque atualizado, pagamento a fornecedor), com descrição e valor editáveis
- **Receita declarada = soma das linhas de receita** (`sincronizarReceita()`): cada linha tem o seu valor,
  então adicionar ou remover linha muda a receita do mês — o débito da CBS sempre fecha com o PGDAS.
  A linha "Receita declarada" da DRE é só o total (não é campo). Toda linha de receita se chama
  **"Receita PGDAS"** (`NOME_RECEITA`), sem campo de nome na tabela nem na memória: o que diferencia uma
  linha da outra é a situação no DAS. Só as linhas de crédito continuam com nome livre.
- **Compras → crédito (itemizado):** cada linha de compra tem a sua regra e alíquota, e o crédito das
  compras é a **soma das linhas** (`credLinha`, a mesma função das despesas). "Alíquota das compras"
  é premissa (padrão 9%): vale para as linhas novas e propaga para as que já têm crédito.
  O mecanismo antigo — uma compra só, com linhas de crédito atadas a "parte das compras" e a etiqueta
  "compras"/"base fixa" — **saiu**: as duas coisas modelavam o mesmo crédito, e juntas contariam duas
  vezes. As linhas de crédito da memória seguem existindo para crédito que não vem de compra, sempre
  com base digitada
- **Padrão x Excel:** com Receita PGDAS a 8% e compras a 9%, a CBS padrão do Aragão é R$ 2.272,19.
  Para reproduzir o Excel (R$ 815,54): receita 2.734,37 integral + 103.685,52 reduzida; e as compras
  em duas linhas — 60.372,13 a 3,2% e 1.867,18 a 8%
- **Premissas** "Alíquota geral" e "Alíquota das compras" propagam para as linhas de receita, de crédito
  e de despesa com crédito. A premissa **"Alíquota reduzida" saiu da tela** (13/09/2026): a redução é
  escolhida na linha, na hora de lançar, e o campo só existia para alimentar a de 60%
- **Alíquota sempre calculada pelo tipo, na receita e no crédito** (`normalizarLinhas()`): na memória ela
  é texto, não campo — quem manda é o tipo da linha. A migração v6 acerta meses salvos com alíquota antiga
  gravada na linha (ex.: 15,33%, que é a parcela da CBS no DAS, não a alíquota da CBS). A **linha de
  crédito passou a seguir a mesma regra** (13/09/2026): antes tinha campo de alíquota editável, mas a
  alíquota geral já a sobrescrevia — o campo aceitava um número e o desfazia depois. Agora as duas listas
  são normalizadas em todo carregamento, e a linha de crédito nova entra pelo tipo (`aliqTipo('geral')`)
  em vez da alíquota das compras
- **Tipo de alíquota** de cada débito e crédito (etiqueta ao passar o mouse): Alíquota cheia,
  Redução de 30% (geral × 0,7), **Redução de 40% (geral × 0,6)**, Redução de 50% (geral × 0,5),
  **Redução de 60% (geral × 0,4)**, Redução de 70% (geral × 0,3) e Alíquota zero. Guardado em `r[3]`:
  `geral`, `red30`, `red40`, `red50`, `reduzida`, `red70`, `zero` (o nome `reduzida` é herança de
  quando ela era a única redução).
  **A de 60% deixou de ter premissa própria** (13/09/2026): digitada à parte, ela descolava da geral —
  a tela do usuário mostrava geral 9,00% com a reduzida parada em 3,20%, que é 40% de 8%. Em troca,
  perdeu-se a saída para um caso em que a lei dê um número que não seja exatamente 40% da cheia; se
  aparecer, o lugar dele é uma alíquota própria **na linha**, não uma premissa do mês
- **Receita por tipo** (detalhamento da receita, aba Resultado — seção 2 da planilha "Simples CBS
  Tradicional vs Híbrido"): tipo, receita, **situação no DAS** (`r[5]`: Integral, ICMS-ST, Monofásico,
  ICMS-ST + monofásico, ISS retido), **tipo da CBS por fora** (com a alíquota da linha embaixo, para não
  confundir a alíquota da CBS com a parcela dela dentro do DAS) e débito. São as mesmas linhas do débito
  da memória da Reforma — editar em uma vale para a outra
- **Simples Nacional do mês** — `rSimplesMes()`, cartão **acima da DRE**: anexo do Simples (`anexo`, da
  empresa) e receita dos 12 meses (`monthly.rbt12`, do mês), com a faixa e a alíquota efetiva ao lado
- **Mais de uma atividade, mais de um anexo** (`anexoLinha()`, `anexoEmpresa()`): cada linha de receita
  tem o seu anexo, escolhido embaixo do nome na tabela (`r[6]`). A **receita dos 12 meses é uma só**,
  então a **faixa é a mesma** para todos — o que muda é a alíquota efetiva e a fatia da CBS, que saem
  da tabela de cada anexo. O DAS é a soma linha a linha, e o rótulo lista uma efetiva por anexo com
  receita no mês ("*5ª faixa · I 9,91% · V 19,88%*"); com um anexo só, volta a "*efetiva 9,91%*".
  **Sem migração:** linha sem anexo próprio usa o da empresa, então mês salvo antes disso não muda de
  número. O **Fator R** (Anexo V ↔ III pela folha) **não é calculado** — decisão do usuário: o
  enquadramento é o que ele escolher na linha.
  Com **mais de um anexo entre as linhas** (`variosAnexos()`), o campo **"Anexo do Simples" some da tela**
  (`data-v="r.umAnexo"`): não existe *o* anexo da empresa, e o campo único mostrava o de uma linha como se
  fosse o de todas. O subtítulo do cartão acompanha — "*A receita dos últimos 12 meses dá a faixa; o anexo
  de cada linha de receita dá a sua alíquota efetiva*" —, e quem quiser trocar o anexo o faz na própria
  linha, onde ele já estava. A mensagem "*escolha o anexo*" passou a testar o **anexo efetivo**
  (`anexoEmpresa()`) e não `S.anexo`: com o anexo só nas linhas o cálculo roda, e a tela mandava escolher
  por um campo que nesse caso nem está mais lá
- **Receita dos 12 meses zerada** (`baseRbt12()`): são **dois casos diferentes**, e só quem preenche
  sabe qual é — por isso aparece um campo **Situação** ao lado, só quando o RBT12 está zerado
  (`monthly.inicioAtividade`):
  - **Sem movimento** (padrão): a empresa existe há mais de 12 meses e não faturou. O RBT12 é zero
    mesmo, e zero é a **1ª faixa** do anexo — onde não há parcela a deduzir, então a efetiva é a
    alíquota nominal. A tela mostra "*1ª faixa · efetiva 15,50% · sem receita nos 12 meses*"
  - **Início de atividade**: a faixa sai da **receita do próprio mês × 12**, a proporcionalização da
    LC 123/2006 (art. 18, §2º) e da Resolução CGSN 140/2018 (art. 21). A tela mostra "*2ª faixa ·
    efetiva 16,48% · início de atividade: receita do mês × 12*"
  - informar o RBT12 volta a mandar em qualquer caso, e o campo Situação some
- **Apuração do mês** — `rApuracaoSimples()`, **fora da tela por enquanto** (decisão do usuário: entra
  depois, no fim da DRE, quando receitas e despesas já foram demonstradas). O cálculo continua valendo
  (`segregacao()`, `dasBase`) e alimenta o quadro Tradicional × Híbrido. Quando voltar, traz: receita
  dos 12 meses (`monthly.rbt12`, do mês) dão a faixa e a alíquota efetiva; em seguida o DAS que sai da
  receita por tipo, o **DAS declarado** (campo ligado à linha do Simples nas despesas tributárias, sem
  precisar de "Editar valores") e a **conferência** entre os dois (tolerância de R$ 1,00; sem DAS
  declarado, nada é comparado). ICMS-ST tira o ICMS da partilha, monofásico tira PIS/Cofins (até 2026;
  a CBS a partir de 2027, pelo ano da competência), ISS retido tira o ISS. Dezembro do Aragão fecha
  exato: medicamentos 103.685,52 com ICMS-ST + monofásico e o restante 2.734,37 integral dão
  R$ 4.889,93. Tabelas dos Anexos I–V (LC 123) em `ANEXOS`; 6ª faixa com ICMS/ISS pela 5ª; ISS acima
  de 5% passa o excedente para os federais
- **CBS dentro do DAS:** com anexo e receita dos 12 meses, sai da receita por tipo (CBS de 2027 sobre as
  linhas que não são monofásicas ÷ DAS calculado, aplicado ao DAS declarado). Sem eles, vale a
  "Parcela da CBS no Simples" informada (padrão 15,33%). Com a receita toda integral dá os mesmos 15,33%.
  Enquanto o DAS declarado estiver zerado, a base é o DAS calculado (`dasBase`, legenda "do DAS calculado")
- **A linha do DAS é achada pelo nome** (`linhaSimples`, `/^simples nacional/i`). Sem ela — renomeada ou
  removida —, o painel usa o **DAS calculado** pela tabela. Antes caía na primeira despesa tributária da
  lista, o que faria o INSS virar "o DAS" sem avisar; com as listas editáveis isso ficou a um clique
- **As duas CBS lado a lado** (fim do cartão, também fora da tela por enquanto): a de dentro é uma fatia do DAS (15,33% dele) e a de fora
  incide sobre a receita (8% dela) — bases diferentes, por isso aparecem com a legenda de cada uma, mais
  o DAS sem a CBS e a conclusão ("Com a CBS por fora, o mês custa R$ X a mais", com o total ao lado)
- **Tradicional × Híbrido** (último bloco da aba Resultado — seção 4 da planilha), **um cartão por regime**
  (16/09/2026, a partir de um modelo do usuário, nas cores do sistema: cantos retos, sem sombra). Na tela o
  regime de hoje chama-se **tradicional** (era "convencional" até 17/09/2026 — o usuário achou o termo mais
  claro para o cliente); no código as chaves continuam `conv` (`k.conv`, `lp.conv`, `convGanha`), para não
  mexer no que já está salvo no banco:
  - **Simples tradicional:** DAS total em destaque, alíquota efetiva e, numa faixa branca sobre o cartão
    cinza, a CBS dentro do DAS — em tom apagado porque é parte do DAS, não soma a ele.
  - **Regime híbrido:** DAS sem CBS, CBS por fora (com "crédito de R$ X vai para o mês seguinte" quando
    credora), **IBS por fora só quando informado** (`monthly.ibs`), total em faixa branca e alíquota efetiva.
  - **Composição dos tributos do mês** no pé de cada cartão, alinhada entre os dois (`margin-top:auto`):
    barra empilhada (DAS em cinza `--muted-2`, CBS `--brand`, IBS `--line-3`) e legenda com marcador quadrado
    (`.cg-q`, o mesmo da pizza), percentual e valor. **Cada barra é o total do próprio regime** — quem
    compara os dois é o destaque do cartão vencedor. No tradicional a CBS dá 15,33% do DAS: é a parcela.
    O DAS era preto (17/09/2026): pesava mais que a parte vermelha, que é a CBS, o que se compara ali.
  - Embaixo de cada composição, a **carga tributária do mês** (todas as despesas tributárias; no híbrido,
    trocando o DAS pelo par DAS sem CBS + CBS).
  - **Quem sai mais barato** (17/09/2026): o cartão vencedor fica branco, com filete verde no topo, etiqueta
    "MAIS BARATO NO MÊS" com troféu (SVG `TROFEU`, não emoji) em verde suave e a diferença em reais embaixo do
    valor; empate não destaca nenhum. Substituiu a faixa preta embaixo dos cartões. Testados e recusados: faixa
    clara com filete (comparada na tela), etiqueta preta e contorno escuro no cartão. O mesmo vale no quadro
    do Lucro Presumido.
  - Depois dos cartões: quanto a alíquota efetiva sobe
    ou cai em pontos percentuais, o ponto de equilíbrio e, sem IBS informado, a nota "*O IBS ainda não é
    calculado: os dois cenários comparam só o DAS e a CBS*".
  - **O modelo trazia "IBS dentro do DAS"**, que ficou de fora: a partilha do Simples no painel não separa
    IBS (pendência 2), e inventar esse número seria pior que não mostrá-lo.
  - **Celular:** abaixo de 800px os cartões empilham; abaixo de 640px a legenda vira uma fatia por linha —
    em três colunas o "R$" quebrava longe do número. Conferido a 360px reais num iframe, porque o Chrome
    sem janela no Windows não desce de 484px de largura (o teste "celular 400px" mede, na prática, 467px)
- **Memória de cálculo da CBS num cartão só** (17/09/2026): o gráfico "Débito, crédito e saldo" ao lado saiu —
  repetia os três números. Fechada, a memória mostra débito e crédito com a barra na própria linha (`.sum-bar`):
  débito em grafite, crédito em tons de verde (é a favor da empresa), grafite e verde separados pela claridade
  e não só pela cor. **De onde vem o crédito:** a barra do crédito é empilhada por origem — compras, despesas,
  outras linhas e saldo do mês anterior — com a legenda em reais e % embaixo. **CBS a pagar** sem o bloco
  vermelho: fundo claro, filete e valor em vermelho, como a linha do topo; com sobra de crédito, verde. Aberta,
  a memória ocupa a largura toda.
- **Fechamento da DRE** (17/09/2026): "Resultado líquido" com traço duplo em cima e fundo bege claro, a convenção
  do total final em demonstrativo impresso, no lugar do bloco preto (a faixa com filete à esquerda foi comparada
  na tela e perdeu). O "Lucro operacional bruto" ficou sem o fundo rosa: chamava mais atenção que o resultado.
- **Cores:** preto para estrutura e totais; vermelho da marca para a CBS; verde só para o que é a favor da
  empresa (crédito, vencedor), sempre suave e com texto ou ícone junto; no máximo uma cor de destaque por bloco.
  Vermelho e verde não fazem par de "ruim × bom" lado a lado.
- **Ponto de equilíbrio** (`textoEquilibrio()`, no quadro Tradicional × Híbrido, fim da aba Resultado):
  quanto falta para o híbrido empatar com o tradicional, ou quanta folga ele tem, dito **no gasto** que
  produz o crédito: "*faltam no mês R$ 16.917,42 em compras (9%) ou R$ 19.032,10 em despesas com direito
  a crédito (8%)*". Compra e despesa creditável servem igual; o que muda é a alíquota de cada uma, e por
  isso o gasto necessário é diferente (quanto maior a alíquota, menos gasto). Com as duas alíquotas iguais
  vira uma conversão só; com uma delas zerada, sobra a outra; sem nenhuma — única situação em que não há
  conversão possível — fica o crédito em reais. **O crédito não entra no texto** quando há conversão: é o
  mesmo número da barra preta logo acima, e repeti-lo atrasava a leitura até o que interessa. O texto diz
  "despesas **com direito a crédito**" de propósito: folha e retirada de sócio não geram crédito de CBS,
  e "despesas" sem qualificar convida a somá-las. O "no mês" vem antes do valor porque no fim da frase
  cairia depois do parêntese da alíquota, longe do verbo.
  O IBS a pagar (`monthly.ibs`) e a parcela da CBS (`cbsSobreEfetiva`,
  padrão 15,33%) continuam no estado e no cálculo, mas **sem campo na tela** (decisão do usuário)
- **Cadeia nos textos:** em "Compras do mês", avisa quantos fornecedores não geram crédito cheio
- **Menu Opções:** Editar valores, Personalizar (nome, períodos, rodapé, 2 cores, logo),
  Modo apresentação, Imprimir, Salvar, Baixar HTML, Restaurar padrão, Limpar tudo
- **Resumo do cliente** (handoff seção 5): a aba ficou só com a **cadeia de crédito** e os **produtos e
  serviços**, cada um com o cadastro **recolhido por padrão** ("Ver cadastro" / "Ocultar cadastro",
  `ui.cadastro`): sobra a frase-resumo e os dois gráficos, que é o que serve à conversa com o cliente.
  Quem clica em "+ adicionar" abre o cadastro junto (adicionar é editar). O **Modo apresentação**
  recolhe os dois e não oferece o botão. Os blocos ficam **um abaixo do outro**, em largura cheia
  (chegou a existir um lado a lado com os dois recolhidos; o usuário preferiu empilhado, que mantém a
  pizza ao lado das barras). O aviso de CNPJ inválido continua visível mesmo recolhido — é problema a
  resolver, não detalhe. "Para onde foi a receita", os quatro cartões ("O mês em quatro números") e o "O que
  observar" foram retirados a pedido do usuário — os mesmos números já estão na faixa de indicadores do
  topo e no quadro Tradicional × Híbrido. Saíram com eles `textoObservar()` e `textoClientesCadeia()`
- **Cadeia de crédito** (fim do Resumo do cliente, handoff seção 5.1, gráficos **A e B**: as barras
  por regime e, ao lado, a pizza de 108px com a proporção do total. O handoff pedia escolher só um;
  o usuário pediu os dois — as barras quebram por regime, a pizza dá a proporção. A legenda é única,
  ao lado da pizza, com o percentual de cada categoria. O anel (donut) chegou a ser testado nos dois
  blocos e foi recusado pelo usuário: fica a pizza cheia):
  - cabeçalho com a frase que responde "quantos geram crédito" e o alternador Fornecedores / Clientes
    com as contagens; concordância obrigatória (singular/plural; fornecedor *gera crédito*, cliente
    *aproveita o crédito*; "todos" e "nenhum") em `resumoCadeia()`
  - gráfico: uma barra por regime (Simples → Presumido → Real → demais), segmentos gera / parcial /
    não gera medidos sobre o total de cadastros; legenda só com as categorias que existem (`graficoCadeia()`)
  - faixa de alerta quando há CNPJ que não confere (dígito verificador, aceita o alfanumérico)
  - tabela: CNPJ com ponto (vermelho e número em vermelho se inválido), nome, regime em cinza, gera
    crédito Sim / **Parcial em vermelho e negrito** (mantido a pedido, fora do handoff) / Não /
    A definir. O handoff destacava o "Não"; o usuário pediu o vermelho no **parcial**, e a tabela
    seguiu o gráfico para a tela inteira dizer a mesma coisa;
    campos parecem texto até passar o mouse; × sempre visível; rodapé com
    "+ adicionar" e a legenda da visão; estado vazio explicando por que cadastrar
  - dados em `cadeia.fornecedores` e `cadeia.clientes` (`[cnpj, nome, regime, 'sim'|'parcial'|'nao'|'']`),
    começam vazios e ficam no banco (tabela `parceiros`) ou no Baixar HTML — nunca no código
- **O vermelho do painel é o da logo** (18/09/2026): era `#B3122B`, um carmim com azul na mistura; a logo do
  escritório usa `#A80000` (medido nos pixels dela). Com o carmim, os tons claros da rampa da CBS puxavam para o
  rosa e destoavam da marca. Trocado no token, no estado padrão e no fallback do `refresh()`.
- **Cores da cadeia de crédito** (18/09/2026): "gera crédito" era preto chapado e "parcial", o vermelho da marca —
  duas cores fortes escolhidas por acaso para um dado que tem ordem. Viraram escala neutra (`--cad-sim`,
  `--cad-parcial`, `--cad-nao`): grafite em quem gera crédito, cinza médio no parcial, cinza claro em quem não gera.
  A versão em verde (gerar crédito é a favor da empresa) foi comparada na tela e recusada, e o grafite que veio
  depois também: frio demais ao lado do bege e do vermelho. A escala terrosa ganhou de outra na família do vermelho
  da logo — com as duas vermelhas, cadeia e CBS se confundiam.
- **Com uma categoria só não há gráfico** (`discoCg`, `soloCg`): um disco inteiro de uma cor não compara nada —
  acontecia sempre que todos os itens caíam na mesma faixa (todos na alíquota cheia, todos gerando crédito). O anel
  com a contagem no meio foi testado e recusado, e o número grande também ("grosseiro"): ficou o chapéu em mono
  ("100% DOS ITENS") e uma linha de leitura com o que faltava — a contagem, a faixa e a alíquota que vale para
  todos ("17 itens · CBS de 8,00%"). O chapéu é sempre plural: com um cadastro só saía "100% dos item".
  Com duas faixas ou mais, segue a pizza.
- **Cores das faixas de redução da CBS** (18/09/2026): eram cinza, grafite, preto e vermelho misturados — cores
  de categoria para um dado que é **escala**. Viraram uma rampa de um tom só (`--cbs-6` … `--cbs-1`): o vermelho
  da marca na alíquota cheia, clareando conforme a redução cresce, para a leitura ser "quanto mais forte, mais
  imposto". A **alíquota zero fica fora da rampa**, em neutro (`--cbs-0`): nenhum imposto não é um vermelho fraco.
  As fatias da pizza deixaram de se encostar (meio grau da cor do cartão entre elas separa tons vizinhos), o disco
  ganhou filete — sem ele os passos claros somem no cartão — e as amostras da legenda também. O contraste baixo dos
  passos claros é compensado por nome e percentual ao lado de cada faixa, que é o que a leitura exige.
- **Produtos e serviços** (logo abaixo da cadeia de crédito, mesmo vocabulário visual): cadastro do que
  a empresa vende, com as **duas alíquotas calculadas** — nada de digitar percentual:
  - colunas: **Nome**, **Tipo** (Produto / Serviço), **NCM / NBS**, **cClassTrib**, **Redução da CBS**
    e **Alíquota reduzida**
  - os códigos seguem o tipo: produto mostra o campo de **NCM**; serviço, o de **NBS**. O **cClassTrib**
    vale para os dois (é exigido de todo item no layout da NF-e da reforma) e só espera o tipo ser
    escolhido; enquanto não for, os dois campos ficam com um traço. Cada código tem a sua posição na linha (`3` NCM, `4` NBS, `5` cClassTrib),
    então trocar o tipo não apaga o que já foi digitado no outro. O seletor de tipo é `data-nat` e chama
    `render()` — muda a estrutura da linha, não só os números, e `refresh()` sozinho não redesenharia
  - **Redução da CBS** (cheia, −30%, −60%, −70%, zero) → dá a **alíquota reduzida**, por `aliqTipo()`,
    seguindo as premissas do mês. É o único número da tabela: situação no DAS e alíquota efetiva
    saíram a pedido do usuário — são conversa da apuração do mês, não do cadastro do item
  - a 3ª posição da linha guardou "situação no DAS" na primeira versão do bloco; valor que não seja
    `produto`/`servico` cai em "Escolha…" em vez de aparecer como lixo
  - gráficos por **quantidade de itens** em cada faixa (decisão do usuário): uma barra por faixa e um
    **pizza** com a proporção, nas mesmas cores. A escala marca a **exceção**, não o padrão: alíquota
    cheia no tom mais claro (`line-2`) e, quanto maior a redução, mais escuro, com a alíquota zero em
    `brand`. Antes era o contrário e um catálogo quase todo cheio virava um disco preto
  - dados em `produtos` (`[nome, tipo, natureza, NCM, NBS, cClassTrib]`), **por empresa** (tabela
    `produtos`, como a cadeia): o que for cadastrado em agosto aparece em junho. Segue também dentro do
    estado do mês, que é o que vale enquanto o banco não tiver a migração; "Limpar tudo" preserva
- **Limpar tudo:** dois cliques; zera valores e mantém categorias, alíquotas, premissas, identidade
  **e o cadastro da empresa** — cadeia de crédito e produtos ficam, porque são estrutura e custam caro
  para refazer (CNPJ, NCM, NBS). Para começar do zero existe "+ Nova empresa", que nasce sem os dois
- **Modo apresentação** e link `#cliente` (abre no Resumo do cliente) deixam os campos só leitura. Desde
  16/09/2026, feito para a reunião com o cliente:
  - **Testados e recusados pelo usuário** (17/09/2026, código removido): capa com três mensagens do mês (resultado,
    regime, ponto de atenção), passo a passo com setas, cartão "Mês a mês" e gráfico dos últimos meses. A apresentação
    é a página inteira; o que sobrou é o que está aqui embaixo.
  - **Tela cheia** ao lado de "Sair da apresentação" (no link do cliente, só ela); o rótulo acompanha o Esc pelo
    `fullscreenchange`, sem redesenhar. Sair da apresentação sai da tela cheia.
  - **Letra 15% maior** em tela a partir de 900px: `zoom:1.15` na `.page` com a largura máxima dividida por 1,15
    (inclusive a barra fixa), para não criar rolagem lateral. **Contraste de projetor:** `--muted*` e `--line*`
    mais escuros em `body.present`, nos dois temas.
  - **Menos texto:** somem subtítulos de cartão (`.card-h .sub`), notas de método (`.nota`: IBS não calculado,
    rodapés do Presumido) e as premissas do Presumido; frases de conclusão (variação, equilíbrio) ficam.
  - **Maquinaria recolhida:** detalhamento, memória da CBS, estoque e trimestres do Presumido fecham ao entrar
    (os botões "Ver" continuam) e voltam como estavam ao sair (`ui.antesDeApresentar`).
  - **"digitar" do DAS calculado** não existe na apresentação e a ação recusa se chamada: alterava o mês.
  - **Apontador** (17/09/2026): clicar numa linha (DRE, indicadores, cartões, memória, tabelas) destaca ela — cresce
    6%, ganha fundo e sombra — e apaga as outras (`body.realcando`, opacidade .22); clicar de novo, clicar fora ou
    Esc desfaz, e `render()` limpa. Enquanto há realce, `.scroll-x` não rola: a linha crescida dentro de uma área que
    rola ligava as duas barras de rolagem.
  - **Cadastro aberto na apresentação** (17/09/2026): "Ver cadastro" (cadeia de crédito e produtos) passou a valer
    também no modo apresentação, só de leitura — sem ele não dava para mostrar a lista de fornecedores ao cliente.
    Ao entrar, os cadastros começam fechados, como o resto da maquinaria.
  - **A competência continua trocável** (18/09/2026): a barra de seleção sumia inteira na apresentação e não dava
    para mudar de mês no meio da reunião. Agora ela fica, **só com a competência**: o seletor de empresa sai (a
    lista é de outros clientes e não deve aparecer na tela de um deles), e o status e o botão Salvar também. No modo
    local, sem banco, a barra segue oculta — o aviso "nada é salvo" não é assunto do cliente.
  - **Colunas do detalhamento elásticas** (17/09/2026): `.g5` e `.grec` tinham colunas fixas (somavam ~645px) e
    caíam na rolagem lateral em janela menor ou com zoom do navegador; agora encolhem até ~475px.
- **Comparação com o mês anterior** (16/09/2026): ▲/▼ ao lado da receita e do resultado na DRE e do Simples na
  faixa de indicadores — receita e DAS em %, resultado em reais (percentual sobre resultado negativo não diz nada).
  Compara com o **último mês salvo** antes deste (`anterior` do `carregar_painel`, que já vinha para a herança) e
  diz qual ("vs mar/2024"); mês salvo sem resumo é recalculado pelos dados. Some no primeiro mês e no modo local.
  Testes: seção 16 do painel (recolher e voltar, zoom, menos texto, "digitar", apontador) e 3h do banco.
- **Salvar no banco** (com Supabase configurado): barra abaixo do cabeçalho com Empresa, Competência,
  situação ("Salvo às 10:32" / "Alterações não salvas") e botão **Salvar** (ou Ctrl+S). Ver a seção
  "Banco de dados". Sem Supabase, a barra avisa "Modo local" e o menu mantém o `window.storage`
- **Baixar HTML:** grava o estado num `<script id="estado-salvo">` no `<head>`, inserido pelo DOM, e
  tira a configuração do banco — o arquivo funciona sozinho para quem não tem login

### Como a tela atualiza
`render()` monta a estrutura (troca de aba, adicionar/remover linha, detalhamento).
`refresh()` recalcula e escreve só os textos marcados com `data-o`, as larguras das barras
(`data-w`) e os campos fora de foco — por isso digitar recalcula tudo sem perder o cursor.
Campos: `data-b` = caminho no estado, `data-f` = formato (`brl`, `base`, `pct`, `pct0`, `txt`, `cnpj`).
Parser pt-BR `num()`: com vírgula, ela é o decimal; sem vírgula, o ponto é decimal.

### Armazenamento no navegador
O painel publicado roda na Vercel, então usa `localStorage` só para a **sessão de login**
(`dre.sessao`) e a **última empresa/mês aberta** (`dre.ultimo`), sempre dentro de `try/catch`
(objeto `guarda`): se o navegador bloquear, o painel funciona e só pede login de novo.
Os dados em si ficam no Supabase, nunca no navegador.

### Modelo de dados (`defaults()`, `v: 2`)
```js
monthly.ga = [ [label, valor, %base, alíquota], ... ]   // crédito por item
monthly.reforma = {
  aliqGeral, aliqCompras, cbsSobreEfetiva, saldoCredorAnterior,
  debitos:  [ [nome, base, alíquota, 'geral'|'reduzida', 'pgdas'?], ... ], // 'pgdas' = base é a receita
                                                                           // declarada menos as outras linhas
  creditos: [ [nome, base, alíquota, 'geral'|'reduzida'], ... ]          // crédito que não vem de compra
}
monthly.compras = [ [item, valor, %base, alíquota], ... ]   // compras do mês, como monthly.ga
monthly.estoque = [ [descrição, valor], ... ]   // inventário, estoque atualizado, pagamento a fornecedor
```
Estados salvos no modelo antigo (v1: `creditosCompra`, `creditoGeralAliq`, sem tipo) são
migrados em `migrar()` e mesclados em profundidade com os padrões. Estados anteriores à v3
recebem `aliqCompras = 0`, para o crédito das compras não somar em cima dos créditos já lançados.
Estados anteriores à v4 recebem `anexo = ''` e `rbt12 = 0`: não herdam os do cliente de exemplo e
seguem com a parcela da CBS informada. Na **v7**, `compraMercadoria` (um número) vira a lista
`compras` com uma linha pela alíquota que estava em uso, e as linhas de crédito atadas a "parte das
compras" viram base fixa — o crédito total não muda.

"Simples sem a CBS" é **calculado** (Simples − CBS dentro do DAS, pela receita por tipo ou pela parcela
informada), não constante como no handoff — com 15,33% dá os mesmos 4.140,30.

As categorias são **editáveis e ilimitadas** justamente porque o escritório
atende ramos diferentes — não pode haver "medicamento" hardcoded.

---

## Banco de dados (Supabase)

Tudo o que é preenchido no painel fica salvo **por empresa e por mês**. Só a equipe acessa,
com e-mail e senha. O painel fala direto com a API do Supabase (sem biblioteca), e quem
protege os dados é o **RLS** do banco: a chave pública sozinha não lê nada.

### Configurar (uma vez)

1. **Criar o projeto:** supabase.com → New project (região São Paulo, se disponível).
2. **Criar as tabelas:** SQL Editor → cole `supabase/migrations/20260911120000_estrutura_inicial.sql`
   inteiro → Run; depois o mesmo com `20260912120000_resumo_e_heranca.sql` (resumo do mês,
   herança e a função `resumos`) e `20260912130000_produtos_por_empresa.sql` (catálogo por empresa,
   com backfill do que já estava salvo), e por último `20260916130000_protecao_dos_dados.sql`
   (lixeira, versões e trava — ver "Proteção dos dados" abaixo) e `20260923120000_fator_r_por_empresa.sql`
   (a coluna que liga o Fator R por empresa). Para conferir, rode
   `supabase/scripts/conferir_instalacao.sql`.
   Enquanto a segunda migração não for aplicada o painel continua funcionando — só não herda
   nada no mês novo e a aba Anual não soma os meses.
3. **Fechar o cadastro público:** Authentication → Sign In / Providers → desligue
   "Allow new users to sign up". Assim só entra quem você criar.
4. **Criar os usuários da equipe:** Authentication → Users → Add user → Create new user
   (e-mail, senha, marque "Auto Confirm User"). Depois, no SQL Editor, rode
   `supabase/scripts/adicionar_membro.sql` com o e-mail de cada pessoa. Sem esse passo o
   login funciona, mas o painel avisa que a pessoa não faz parte da equipe.
5. **Copiar as chaves:** Project Settings → API → **Project URL** e a chave **anon** ou
   **publishable**. Nunca use a `service_role`/`secret` — os dois scripts de build recusam.
6. **Vercel:** Settings → Environment Variables → `SUPABASE_URL` e `SUPABASE_ANON_KEY`
   (Production e Preview) → Deployments → Redeploy. O log do build confirma
   "Painel publicado com o banco de dados".
7. **No computador (opcional):** copie `.env.example` para `.env`, preencha e rode
   `python src/gerar_dashboard.py` — abre `build/DRE_Dashboard_banco.html` já ligado ao banco.

Com a CLI, os passos 2 e 3 viram: `npx supabase init`, `npx supabase link --project-ref <ref>`,
`npx supabase db push` (a migração já está em `supabase/migrations/`).

### Tabelas

| Tabela | Conteúdo |
|---|---|
| `membros` | quem da equipe acessa (`user_id` do Supabase Auth, nome, papel) |
| `empresas` | clientes do escritório (nome, CNPJ único, ramo, `fator_r`: acompanha o Fator R) |
| `competencias` | um painel por empresa e mês: `periodo` (dia 1), `dados` (jsonb com o estado inteiro, sem a cadeia), `resumo` (números já calculados do mês), `atualizado_em/por` |
| `parceiros` | cadeia de crédito da empresa: tipo, CNPJ, nome, regime, gera crédito, ordem |
| `produtos` | catálogo da empresa: nome, tipo da alíquota, produto/serviço, NCM, NBS, cClassTrib, ordem |
| `competencias_lixeira` | mês excluído, inteiro, por 30 dias (gatilho em todo `DELETE`) |
| `competencias_versoes` | estado anterior do mês a cada alteração dos `dados` (30 por mês) |
| `cadastros_versoes` | fornecedores, clientes e catálogo da empresa antes de cada troca (30 por empresa) |

O `resumo` é gravado pelo próprio painel a cada salvamento (`resumoDe()`): receita, DAS, Simples, CBS,
saldo credor, resultado, custos, despesas, compras, alíquota efetiva, RBT12, anexo e faixa. É ele que
permite herdar do mês anterior e somar o exercício sem baixar o estado inteiro de cada mês — e nenhum
imposto é recalculado em SQL. Mês salvo antes desta migração fica com `resumo` nulo; nesse caso o
painel baixa o estado daquele mês e recalcula na hora.

Funções chamadas pelo painel (`/rest/v1/rpc/...`), com RLS valendo dentro delas:
- `carregar_painel(empresa, período)` → o mês salvo, o mês mais próximo (modelo para mês novo),
  o mês **imediatamente anterior** (`anterior`, origem da herança) e a cadeia.
- `resumos(empresa, de, até)` → os meses do intervalo com `{periodo, resumo, receita}`. Usada pelo
  RBT12 (12 meses anteriores) e pela aba Anual (o exercício).
- `salvar_painel(empresa, período, dados, parceiros, base, resumo, produtos, apagar_listas)` → grava o mês e a cadeia **numa transação**.
  Lista de fornecedores/clientes ou catálogo que chega **vazia** não apaga a da empresa, a não ser com
  `apagar_listas = true`; lista igual à do banco não é regravada; lista que muda deixa a anterior em `cadastros_versoes`.
- `listar_lixeira()` / `restaurar_competencia(id)`, `listar_versoes(empresa, período)` / `restaurar_versao(id)`,
  `listar_versoes_cadastros(empresa)` / `restaurar_cadastros(id)` → lixeira e histórico. Restaurar uma versão guarda
  o estado de agora (dá para desfazer); restaurar da lixeira recusa (`OCUPADO`) se o mês foi recriado no mesmo período.
  `base` é o `atualizado_em` de quando o mês foi aberto: se outra pessoa salvou depois, dá `CONFLITO`
  e o painel pergunta se sobrescreve ou abre a versão salva (`'-infinity'` = criar mês que não pode existir).

### Como o painel usa
- Sem login, nenhum dado aparece. A sessão fica guardada e renova sozinha; se cair no meio do
  trabalho, o painel pede o login e **salva o que estava na tela** depois.
- **Nova empresa** (inclusive a primeira) começa **em branco**: categorias genéricas (`modeloEmBranco()`), as
  alíquotas e regras de crédito padrão e os valores zerados. **Novo mês** copia as categorias do mês salvo mais
  próximo, com os valores zerados. Nenhum dos dois usa mais o exemplo da farmácia (ver "Incidente de 16/09/2026").
- **Empresa sem mês salvo** abre o mês atual e **não grava sozinha**: fica "Alterações não salvas" até alguém salvar.
- **"Restaurar padrão"** só existe no modo local: com banco, ele carregava o exemplo da farmácia na empresa aberta.
- Trocar de empresa/mês ou sair com alterações pendentes pergunta antes: salvar, descartar ou cancelar.
  Fechar a aba com alterações também avisa.
- A cadeia de crédito é por empresa (vale para todos os meses dela).
- **Excluir um mês:** menu "Opções" → "Excluir *mês* do banco", com janela de confirmação (o botão
  padrão é Cancelar). Tira a competência da lista de toda a equipe e **manda para a lixeira por 30 dias**
  (gatilho no banco; o painel continua usando `DELETE`). A cadeia de crédito, que é da empresa, não é tocada.
  Depois abre o mês salvo mais recente — e, se não sobrou nenhum, o mês atual **sem gravar**.
- **Proteção dos dados** (16/09/2026):
  - **Opções → Lixeira:** meses excluídos nos últimos 30 dias, de todas as empresas, com data, autor e receita;
    "Restaurar" devolve o mês como estava (desativado se já houver mês salvo no período).
  - **Opções → Histórico de *mês*:** versões anteriores dos valores do mês e das listas de fornecedores, clientes e
    produtos da empresa; "Restaurar" em qualquer uma (e restaurar também vira versão).
  - **Trava ao salvar:** se a tela não tem fornecedores/clientes ou produtos que a empresa tem no banco, pergunta
    antes — "Manter os salvos" (padrão, devolve as listas à tela) ou "Apagar e salvar". O banco tem a mesma trava:
    vale até para uma versão antiga do painel aberta em outra aba.
  - Painel publicado antes da migração: histórico e lixeira avisam que não estão ativos; "Apagar e salvar" reenvia
    sem o parâmetro novo.
- **Conflito ao salvar** não desliga mais o envio do catálogo: antes, o `CONFLITO` (HTTP 400) caía na regra de
  "banco sem a migração do resumo" e o painel parava de gravar produtos pelo resto da sessão.
- **Mês novo herda do anterior** (janela "Novo mês", uma caixa por item): o **saldo credor da CBS**
  do mês imediatamente anterior vira o crédito inicial deste, e a **receita dos 12 meses** é somada
  pelos meses salvos. Estoque e valores das despesas gerais são opcionais (vêm desmarcados).
  É **cópia etiquetada, não vínculo vivo**: o número fica gravado no mês e editável, a tela diz de
  onde veio ("veio de jan/2026", "somados 12 de 12 meses salvos") e há um "atualizar" ao lado do
  RBT12 para somar de novo. Nunca herda de mês posterior — saldo credor só anda para a frente.
- **Aba Anual → "O ano pelos meses salvos":** tabela mês a mês (receita, DAS, CBS por fora, resultado,
  margem) com totais, leitura do exercício (alíquota efetiva média, carga, qual regime sairia mais
  barato no acumulado, faixa do Simples, melhor e pior mês), alerta de **sublimite (R$ 3,6 mi)** e de
  **exclusão (R$ 4,8 mi)** pelo ritmo do ano e aviso dos meses sem competência salva.
  - **A aba Anual é só isto e o Lucro Presumido** (17/09/2026). Saíram, a pedido do usuário: a "Demonstração de
    resultado — exercício" (era **digitada**, nascia zerada com o mês novo e por isso aparecia em R$ 0,00), a faixa
    de indicadores do topo da aba (que vinha dela) e o botão "Preencher o exercício com estes meses", que só servia
    para abastecê-la — com eles saíram `calcAno`, `preencherAno` e as saídas `a.*`. Antes, em 16/09/2026, já tinham
    saído "Para onde foi a receita" e "Em linguagem simples". `S.annual` continua no estado salvo (mês antigo tem
    esses valores gravados), apenas não é mais mostrado. Sem banco, a aba explica que soma as competências salvas.
  - **CBS do ano = débito menos crédito dos meses** (17/09/2026). Antes somava a CBS paga em cada mês: mês com
    mais crédito que débito entrava como zero, e o crédito que o usuário não transportou **de propósito** (é
    análise dele, mês a mês) sumia da conta do ano. Agora `resumoDe` grava `debito`, `credito` (só o do mês, sem
    o transportado) e `saldoAnterior`; `totaisAno` faz Σdébito − Σcrédito. O transportado não entra de novo:
    transportar ou não muda o mês em que se paga, nunca o ano. Sobrando crédito, a CBS do ano é zero e o saldo
    aparece. A leitura "no acumulado do ano…" e o Presumido usam a mesma conta.
  - **Meses salvos antes disso** não têm débito e crédito no resumo: `carregarAno` recalcula pelo estado salvo,
    buscando só `v`, `anexo`, `mesLabel` e `monthly` (a logo personalizada fica no estado e pode ser grande).
    Ao salvar o mês de novo, o resumo se completa.
  - **Duas colunas, "CBS a pagar" e "CBS crédito"**, cada valor numa só e traço na outra; o total do ano cai numa
    delas. Testado e recusado: "− R$" (parecia prejuízo) e "crédito R$ X" em verde (palavra no meio do número e
    cor destoando do texto). Prejuízo no Resultado sai "− R$ 37.581,55", sem cor.
  - **Clique para conferir** (`ui.cbsAno`): "▸ Débito e crédito da CBS, mês a mês" abre débito, crédito do mês,
    a pagar, crédito, crédito transportado e pago no mês, com a nota da conta do ano — e, se o pago mês a mês
    for diferente, quanto seria e por quê.
- **Aba Anual → "Sair do Simples? Lucro Presumido"** (16/09/2026): estimativa de quanto a empresa pagaria no
  Presumido com os meses salvos do ano, pelas regras de 2027. Só lê — não muda nada no banco.
  - **À vista:** atividade, e dois cartões (modelo Tradicional × Híbrido) com **imposto no ano e carga
    tributária** — Presumido com a composição (IRPJ com adicional, CSLL, CBS por fora, ISS/ICMS, INSS patronal)
    e Simples no melhor cenário, com tradicional e híbrido separados — e a faixa da conclusão. "Ver por
    trimestre" abre a apuração. A primeira versão só mostrava a diferença; o usuário quis ver imposto e carga.
  - **Apuração trimestral** (`calcPresumido`): IRPJ 15% e CSLL 9% sobre receita × presunção; adicional de 10%
    sobre a base do IRPJ acima de R$ 20 mil por mês salvo do trimestre. Mês a mês o adicional sai errado quando
    a receita oscila (150/50/50 mil: 2.800 pelo mês, 2.000 pelo trimestre).
  - **LC 224/2025:** presunção 10% maior sobre a receita acima de R$ 5 mi no ano, R$ 1,25 mi por trimestre
    acumulado, com ajuste negativo nos seguintes; linha e nota só aparecem quando se aplica (regra em disputa,
    ADI 7920).
  - **Presunção por atividade** (`ATIVIDADES`, Lei 9.249/1995 arts. 15 e 20), IRPJ e CSLL separados: serviços
    32/32, hospitalares 8/12, construção com material 8/12, só mão de obra 32/32, transporte de cargas 8/12,
    passageiros 16/12, comércio e indústria 8/12, combustíveis 1,6/12 e "outra" (digita os dois). Sem escolha,
    vem do anexo (I e II comércio; III a V serviços). Guardado em `S.presumido`, que passa de um mês para o outro.
  - **ISS ou ICMS** conforme a atividade (transporte e "outra": os dois). O ISS é carga sobre a receita, informada;
    no Simples os dois estão dentro do DAS, e o ICMS zerado ainda mostra o aviso.
  - **ICMS por débito menos crédito** (18/09/2026, a pedido do usuário — a empresa contribuinte credita o ICMS das
    compras): duas premissas, **ICMS sobre a receita** (débito) e **ICMS sobre as compras** (crédito, `icmsCompras`),
    e a mesma leitura da CBS. Crédito = compras do período (`resumo.compras`, as mesmas do bloco Estoque e compras)
    × a alíquota informada. Trimestre com mais crédito que débito fica negativo e aparece em "Crédito de ICMS";
    no ano, sobrando crédito, o ICMS fica zerado e o saldo vai para o ano seguinte — como na CBS, mas **sem mexer
    no Simples**, onde o ICMS já está dentro do DAS. "▸ ICMS" abre débito, crédito e as compras do período
    (`ui.icmsLP`); o cartão traz "débito de R$ X − crédito de R$ Y". Sem alíquota de compras informada, entra só o
    débito, exatamente como era antes. De passagem, a linha "Crédito de CBS" passou a usar a última coluna em vez
    da quarta: na visão por mês ela não aparecia.
  - **CBS por fora** = débito − crédito dos meses, como na tabela do ano (sem o transportado): por trimestre e, no
    ano, zerada quando sobra crédito — a linha "Crédito de CBS" só aparece nesse caso. "▸ CBS por fora" abre débito
    e crédito de cada trimestre (`ui.cbsLP`); o cartão mostra "débito de R$ X − crédito de R$ Y". IBS fica de fora
    (quase zero até 2028). **Simples** = `das` e `naTransicao` dos resumos; no **Anexo IV** o INSS patronal entra dos dois lados.
  - **Folha:** só as despesas de cada mês salvo (`select=periodo,ga:dados->monthly->ga`, uma consulta ao abrir o
    ano), linhas com folha, salário, funcionário, ordenado ou pró-labore no nome; a nota diz quais entraram.
    Encargos padrão 27,8% (20% + RAT + terceiros); **pró-labore a 20%** (sem RAT nem terceiros, campo próprio
    quando a empresa tem pró-labore). Linha que mistura ("Folha e pró-labore") fica com a alíquota da folha.
  - **Base do INSS** (16/09/2026): no cartão, "base: folha de R$ X × 27,80% + pró-labore de R$ Y × 20,00%";
    na tabela por trimestre a linha do INSS abre (`ui.inssBase`) a base de cálculo, cada despesa que o nome puxou
    com a sua alíquota e a nota (o FGTS fica de fora: é igual nos dois regimes).
  - **Trimestre ou mês** (17/09/2026): um alternador acima da tabela troca as colunas — 4 trimestres ou uma por
    competência salva —, e o Ano fecha sempre. O número de colunas vai em `--cols` (a grade é dinâmica). IRPJ,
    adicional, CSLL e as bases **são trimestrais na lei**: nas colunas de mês aparecem rateados pela receita do mês
    dentro do trimestre (sem receita, divididos igualmente), e a tabela diz isso. Receita, CBS, ISS, ICMS, INSS e o
    Simples são do próprio mês; o ano não muda em nenhuma das visões. No cartão, os valores do ano usam chaves
    `lp.*.ano`, que não dependem do número de colunas.
  - **Leitura da tabela** (18/09/2026): a nota de rodapé saiu — a regra do adicional foi para o próprio rótulo
    da linha ("Adicional do IRPJ / 10% sobre a base acima de R$ 20 mil por mês") e a da CBS já estava dentro da
    linha aberta. A última linha deixou de ser "Presumido − melhor do Simples" e passou a dizer o resultado em
    português (`lp.difRot`): "Simples sai mais barato no ano", com a explicação do sinal embaixo. O regime de
    menor imposto **no ano** leva um troféu ao lado do nome (`lp.venc.total|conv|hibr`). Marcar a célula vencedora
    de cada coluna — com filete verde ou com troféu no número — foi comparado na tela e recusado: poluía a leitura.
  - **A visão por mês arrumada** (18/09/2026): com 8 ou 12 colunas os valores se encavalavam e o total do ano saía
    cortado — a culpa era do `minmax(84px,1fr)`, que prendia a coluna em 84px enquanto o número (que não quebra)
    invadia a vizinha. Agora o mínimo da coluna é o próprio conteúdo e o que não couber rola de lado. Junto disso:
    nas colunas de mês o **"R$" sai** (a unidade aparece uma vez, em "valores em R$", no canto da tabela) e só a
    coluna do Ano mantém o símbolo, porque é ela que fecha a conta e alimenta o cartão; o cabeçalho do mês virou
    "jan" com o ano embaixo; e o **nome da linha e a coluna do Ano ficam presos nas bordas** enquanto o meio rola,
    com uma sombra que aparece só do lado em que há coluna escondida (`marcarRolagemX`, classes `x-esq`/`x-dir`).
  - **Filtros da tabela** (18/09/2026), no mesmo canto do alternador de período:
    - **Coluna sem movimento sai** (`colunasLP`): trimestre ou mês sem receita e sem DAS ocupava a largura de quem
      tem número. Some por padrão, e um botão diz quantos estão escondidos e os devolve (`ui.lpVazias`).
    - **Cenário do Simples** (`ui.lpCenario`): Os dois (padrão), só o Tradicional ou só o Híbrido. Com um cenário
      escolhido, a comparação passa a ser contra ele — e o rótulo diz qual ("Simples tradicional sai mais barato
      no ano", "Carga do simples tradicional"), para nunca comparar contra um número que não está na tela.
    - **Completo × Resumo** (`ui.lpResumo`): o resumo esconde as linhas de apoio (bases do IRPJ e da CSLL, o
      acréscimo da LC 224 e as duas cargas) e deixa receita, impostos, total e comparação — é o que serve na
      apresentação ao cliente.
    - **Os controles cabem em um botão** (`ui.lpMenu`): a linha de sete botões tomava a largura da tabela e foi
      recusada na tela. No lugar, um controle que mostra o estado ("Mês · Os dois cenários · Completo ▾") e abre um
      menu com as três escolhas, no mesmo componente do menu Opções. A outra forma testada — três seletores curtos
      (PERÍODO / COMPARAR COM / DETALHE) — foi comparada na tela e perdeu.
      - **No papel, por trimestre e em resumo** (19/09/2026): a tabela saía cortada — ela é feita para rolar de lado
      na tela (colunas do tamanho do conteúdo, `min-width:640px`) e no papel não há para onde rolar; com 8 ou 12
      colunas de mês, nada cabia em A4. Agora `imprimir()` força **trimestre + resumo**, sem as colunas sem
      movimento, e devolve tudo no `afterprint`; no CSS da folha a `.gpres` perde a largura mínima, as colunas
      encolhem (`minmax(0,1fr)`), a fonte cai para 10,5px e as bordas presas deixam de ser `sticky`.
    - **Mês a mês, em folha deitada** (19/09/2026): a janela de impressão da aba Anual ganhou uma terceira escolha,
      "Mês a mês", que sai em **paisagem** (`@page{size:A4 landscape}`, montado junto com as caixas de margem em
      `prepararFolha`) — em pé, treze colunas não cabem de jeito nenhum. Nela a fonte da tabela cai para 8px,
      os recuos encolhem e **até a coluna do Ano abre mão do "R$"**: são treze colunas e o valor do ano é o mais
      longo. A opção só aparece quando há tabela do Presumido, e vem marcada quando a tela já está no mês a mês.
    - **Testes da folha** (seção 3j do banco, a última das que usam banco porque semeia doze meses): com as regras
      de `@media print` aplicadas e a largura útil do A4 — 186mm em pé, 273mm deitado — nenhuma célula pode ter
      texto maior que a própria célula. A medição é **célula a célula**, não pela tabela: o número é mono e não
      quebra linha, então ele vaza por cima da vizinha sem alargar a grade — foi assim que os cortes passaram.
    - Ficou de fora, de propósito: filtro por tributo (a tabela é curta demais para mais um controle) e "simular
      sem o INSS/ICMS", que parece filtro mas muda a conta — isso vive nas premissas, onde fica evidente.
  - Celular: a tabela mostra só a coluna do ano. Impressão "com o detalhamento" abre a apuração.
  - Testes: seção 15 do painel (conta pura: LC 224 com ajuste, Anexo IV, comércio 8/12 com ICMS, ICMS com crédito
    das compras — trimestre credor e sobra no ano —, atividade pelo anexo) e 3g do banco (trimestres, adicional,
    cartões, atividade pelo seletor, comércio com ICMS, ICMS das compras com a linha aberta).

### Testes
Não há Postgres nesta máquina: o SQL foi validado com o parser do Postgres 17 (libpg_query) e o
painel foi testado contra um servidor que imita o Supabase (login, REST, RPC, conflito, sessão
expirada, lixeira, histórico e trava). Na primeira instalação real, rode `conferir_instalacao.sql` e faça
um salvamento de teste.

A migração de proteção foi validada **no banco real sem gravar nada**: migração e 29 testes numa única
requisição que termina com erro de propósito — o Postgres desfaz tudo. Antes, duas sondas confirmaram que a API
roda a requisição numa transação só e que até `create table` é desfeito; depois, uma consulta confirmou que nada
ficou (sem tabelas novas, `salvar_painel` original, sem empresa de teste).

### Incidente de 16/09/2026 — por que essas proteções existem
Reconstruído pelo registro de requisições do Supabase (a API guarda método, rota, navegador e origem):
- 07:38 e 07:55, no site publicado: "Excluir mês" em jun, mai, abr, mar, fev e jan/2026 da **Consult RL**. O
  `DELETE` apagava de vez e **o projeto não tem backup** (lista de backups vazia, sem PITR): não houve como recuperar.
- 07:55:46, página recarregada: empresa sem nenhum mês → `abrirEmpresa` abriu o mês atual e **gravou sozinho**, montado
  do exemplo da farmácia. O janeiro recriado herdou "Energia / Cagece", "Corpvs Segurança" e o anual inteiro do
  exemplo — nomes de fornecedores reais de outro cliente. Toda empresa nova nascia assim (a marcenaria também).
- Salvar substituía fornecedores/clientes e catálogo da empresa pelo que estava na tela: lista vazia apagava tudo.
- Não foram os testes (servidor simulado, `127.0.0.1`) nem as versões abertas para conferência (só leram; nenhuma
  gravação no dia antes das 07:34).
Lições: todo `DELETE` e toda substituição de lista passam por gatilho/trava no banco; nada grava sem ação da pessoa;
dado de um cliente nunca serve de modelo para outro; ativar backup no Supabase continua recomendado.

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
6. Comparação da carga = **Hoje (Simples declarado)** × **CBS por fora**
   (Simples sem CBS + CBS + IBS), no quadro Tradicional × Híbrido, fim da aba Resultado.

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

2. **IBS ausente.** O sistema só calcula CBS. O total com a CBS por fora está
   incompleto e **subestima** a carga. Há campo de entrada manual do IBS.
   Falta também o cronograma de transição.

3. **15,33% × 15,5%.** A memória RBT12 do cliente usa 15,5% para a mesma conta.
   Deixado editável até ele decidir.

4. **Plano de contas diferente entre as abas.** Anual tem "Fatura Cartão",
   "Funcionários"; mensal tem "HapVida", "Folha". **Contornado (12/09/2026):** o bloco
   "O ano pelos meses salvos" soma os totais de cada competência, não as linhas por nome —
   o anual fecha mesmo com os planos diferentes. Comparar linha a linha continua impossível.

5. **Multi-mês.** ~~Hoje é um mês por arquivo.~~ **Resolvido:** os meses ficam no banco, por
   empresa e competência. O anual soma as competências salvas, o saldo credor da CBS passa de
   um mês para o outro e o RBT12 é somado pelos meses salvos (ver "Banco de dados" e
   `docs/roteiro-mes-novo-e-anual.md`).

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

> O backlog completo — painel de empresas, comparação com o Lucro Presumido, funções de análise e de segurança,
> e a tentativa desfeita da busca NBS × cClassTrib — está em `docs/ideias-guardadas.md` (16/09/2026).

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
8. `mesclar(defaults(), dados)` preenche o que faltar no mês salvo com o **exemplo da farmácia**. Para mês ou empresa
   nova, usar `modeloEmBranco()`, nunca `defaults()`.
9. Erro `CONFLITO` do `salvar_painel` vem como HTTP 400 — o mesmo código de "função não encontrada" em alguns casos.
   Tratar pela mensagem antes de cair em qualquer regra de compatibilidade.
