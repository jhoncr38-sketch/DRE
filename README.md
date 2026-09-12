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
`#EFEEEA`, IBM Plex Sans na interface e IBM Plex Mono em todos os números. Cantos retos,
sem sombras. Só tema claro.

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

- **Cabeçalho e faixa de indicadores** fixos em todas as abas, sem bloco herói (o resultado líquido
  já fecha a DRE e está nos cartões do resumo): Simples Nacional e CBS a pagar no mês; despesas
  operacionais e Simples no ano (o lucro operacional bruto fica só na DRE)
- **Abas:** Resultado · Resumo do cliente (mês) · Anual; setas do teclado navegam. A aba Resultado vai da
  DRE à apuração: Simples Nacional do mês → DRE → Estoque e compras → memória de cálculo da CBS
- **Detalhamento** recolhível e **fechado por padrão** (receita por tipo, despesas com regra de
  crédito/alíquota/crédito e tributárias); "Estoque e compras" tem o seu próprio botão, também fechado
- **Despesas editáveis no detalhamento:** nome e valor de cada despesa são campos (sem precisar de
  "Editar valores"), com "+ adicionar despesa" e × para remover. A despesa nova entra com crédito
  integral pela alíquota geral
- **Regra de crédito por despesa** (no lugar do "% base"): Integral, Redução de 30% (profissões
  regulamentadas: contabilidade, advocacia), Redução de 60%, Redução de 70% (aluguel), Sem crédito e
  "Outra parte…" (janela para digitar o %). Por baixo continua a parte da base (`ga[i][2]`):
  "Sem crédito" zera a alíquota; passar a ter crédito entra pela alíquota geral
- **Memória de cálculo da CBS** recolhível ("Ocultar memória"): fechada, mostra só débito total,
  crédito total e a faixa da CBS; aberta, as premissas e linha a linha
- **CBS Crédito:** quando o crédito passa do débito, a CBS aparece em verde (`--ok #1D7A4E`) como
  "CBS Crédito", com o saldo que vai para o mês seguinte — na faixa da memória, no indicador do topo,
  no Resumo do cliente e no gráfico de débito e crédito. Nunca aparece CBS a pagar negativa
- **Estoque e compras** (aba Resultado): compra de mercadoria do mês, inventário, estoque
  atualizado e pagamento a fornecedor; descrições editáveis em "Editar valores"
- **Receita declarada = soma das linhas de receita** (`sincronizarReceita()`): cada linha tem o seu valor,
  então adicionar ou remover linha muda a receita do mês — o débito da CBS sempre fecha com o PGDAS.
  A linha "Receita declarada" da DRE é só o total (não é campo). Toda linha de receita se chama
  **"Receita PGDAS"** (`NOME_RECEITA`), sem campo de nome na tabela nem na memória: o que diferencia uma
  linha da outra é a situação no DAS. Só as linhas de crédito continuam com nome livre.
- **Compras → crédito:** a linha "Compras do mês" gera crédito com alíquota própria, padrão 9%, editável
  e fora das premissas. Linhas de crédito adicionadas saem das compras (legenda "restante das compras")
  e já vêm com a alíquota das compras; cada uma pode ter base fixa ou ser parte (%) das compras,
  pela etiqueta "compras"/"base fixa". Avisa quando as linhas passam o valor das compras
- **Padrão x Excel:** com Receita PGDAS a 8% e compras a 9%, a CBS padrão do Aragão é R$ 2.272,19.
  Para reproduzir o Excel (R$ 815,54): receita 2.734,37 integral + 103.685,52 reduzida; créditos
  60.372,13 reduzida e 1.867,18 a 8%
- **Premissas** "Alíquota geral" e "Alíquota reduzida" propagam para as linhas de receita, de crédito e
  de despesa com crédito
- **Alíquota da receita sempre calculada pelo tipo:** na memória ela é texto, não campo — quem manda são
  as premissas. A migração v6 acerta meses salvos com alíquota antiga gravada na linha (ex.: 15,33%, que
  é a parcela da CBS no DAS, não a alíquota da CBS). As linhas de crédito seguem com alíquota própria
- **Tipo de alíquota** de cada débito e crédito (etiqueta ao passar o mouse): Alíquota cheia,
  Redução de 30% (geral × 0,7), Redução de 60% (segue a premissa "reduzida"), Redução de 70%
  (geral × 0,3) e Alíquota zero. Guardado em `r[3]`: `geral`, `red30`, `reduzida`, `red70`, `zero`
- **Receita por tipo** (detalhamento da receita, aba Resultado — seção 2 da planilha "Simples CBS
  Convencional vs Híbrido"): tipo, receita, **situação no DAS** (`r[5]`: Integral, ICMS-ST, Monofásico,
  ICMS-ST + monofásico, ISS retido), **tipo da CBS por fora** (com a alíquota da linha embaixo, para não
  confundir a alíquota da CBS com a parcela dela dentro do DAS) e débito. São as mesmas linhas do débito
  da memória da Reforma — editar em uma vale para a outra
- **Simples Nacional do mês** — `rSimplesMes()`, cartão **acima da DRE**: anexo do Simples (`anexo`, da
  empresa) e receita dos 12 meses (`monthly.rbt12`, do mês), com a faixa e a alíquota efetiva ao lado
- **Apuração do mês** — `rApuracaoSimples()`, **fora da tela por enquanto** (decisão do usuário: entra
  depois, no fim da DRE, quando receitas e despesas já foram demonstradas). O cálculo continua valendo
  (`segregacao()`, `dasBase`) e alimenta o quadro Convencional × Híbrido. Quando voltar, traz: receita
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
- **As duas CBS lado a lado** (fim do cartão, também fora da tela por enquanto): a de dentro é uma fatia do DAS (15,33% dele) e a de fora
  incide sobre a receita (8% dela) — bases diferentes, por isso aparecem com a legenda de cada uma, mais
  o DAS sem a CBS e a conclusão ("Com a CBS por fora, o mês custa R$ X a mais", com o total ao lado)
- **Convencional × Híbrido** (último bloco da aba Resultado — seção 4 da planilha): DAS, CBS e total de
  cada regime em números, com uma **barra empilhada** por regime (DAS escuro + CBS em `--brand`, medidas
  pelo maior total), faixa com a decisão (verde quando o híbrido ganha) e o ponto de equilíbrio embaixo.
  A CBS do convencional aparece com a legenda "dentro do DAS" porque não soma no total. Embaixo de cada
  regime, a **carga tributária do mês**: todas as despesas tributárias em reais e em % da receita (no
  híbrido, trocando o DAS pelo par DAS sem CBS + CBS). No total de cada regime vem a **alíquota efetiva**
  (regime ÷ receita) e, abaixo da faixa, quanto ela sobe ou cai de um regime para o outro, em pontos
  percentuais
- **De onde vem o crédito da CBS:** a barra "Crédito de CBS" é empilhada por origem — compras, despesas,
  outras linhas e saldo do mês anterior — com a legenda em reais e % embaixo
- **Ponto de equilíbrio** (`textoEquilibrio()`, no quadro Convencional × Híbrido, fim da aba Resultado):
  quanto faltaria em compras com crédito para o híbrido empatar com o convencional, ou quanto elas podem
  cair com ele ainda mais barato. O IBS a pagar (`monthly.ibs`) e a parcela da CBS (`cbsSobreEfetiva`,
  padrão 15,33%) continuam no estado e no cálculo, mas **sem campo na tela** (decisão do usuário)
- **Cadeia nos textos:** em "Compras do mês", avisa quantos fornecedores não geram crédito cheio
- **Menu Opções:** Editar valores, Personalizar (nome, períodos, rodapé, 2 cores, logo),
  Modo apresentação, Imprimir, Salvar, Baixar HTML, Restaurar padrão, Limpar tudo
- **Resumo do cliente** (handoff seção 5): a aba ficou só com a **cadeia de crédito** e os **produtos e
  serviços**. "Para onde foi a receita", os quatro cartões ("O mês em quatro números") e o "O que
  observar" foram retirados a pedido do usuário — os mesmos números já estão na faixa de indicadores do
  topo e no quadro Convencional × Híbrido. Saíram com eles `textoObservar()` e `textoClientesCadeia()`
- **Cadeia de crédito** (fim do Resumo do cliente, handoff seção 5.1, gráficos **A e B**: as barras
  por regime e, ao lado, a pizza de 108px com a proporção do total. O handoff pedia escolher só um;
  o usuário pediu os dois — as barras quebram por regime, a pizza dá a proporção. A legenda é única,
  ao lado da pizza, com o percentual de cada categoria):
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
  - gráficos por **quantidade de itens** em cada faixa (decisão do usuário): uma barra por faixa e a
    pizza com a proporção, nas mesmas cores (mais escuro = mais imposto; alíquota zero em `brand`)
  - dados em `produtos` (`[nome, tipo, situação]`), por mês — o mês novo herda do modelo; "Limpar tudo" zera
- **Limpar tudo:** dois cliques; zera valores e mantém categorias, alíquotas, premissas e identidade;
  esvazia a cadeia de crédito
- **Modo apresentação** e link `#cliente` (abre no Resumo do cliente) deixam os campos só leitura
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
  aliqGeral, aliqReduzida, aliqCompras, cbsSobreEfetiva, saldoCredorAnterior,
  debitos:  [ [nome, base, alíquota, 'geral'|'reduzida', 'pgdas'?], ... ], // 'pgdas' = base é a receita
                                                                           // declarada menos as outras linhas
  creditos: [ [nome, base, alíquota, 'geral'|'reduzida', parte], ... ]   // parte (opcional) = fração
}                                                                          // das compras; base = compras × parte
monthly.compraMercadoria = 62239.31
monthly.estoque = [ [descrição, valor], ... ]   // inventário, estoque atualizado, pagamento a fornecedor
```
Estados salvos no modelo antigo (v1: `creditosCompra`, `creditoGeralAliq`, sem tipo) são
migrados em `migrar()` e mesclados em profundidade com os padrões. Estados anteriores à v3
recebem `aliqCompras = 0`, para o crédito das compras não somar em cima dos créditos já lançados.
Estados anteriores à v4 recebem `anexo = ''` e `rbt12 = 0`: não herdam os do cliente de exemplo e
seguem com a parcela da CBS informada.

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
   herança e a função `resumos`). Para conferir, rode `supabase/scripts/conferir_instalacao.sql`.
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
| `empresas` | clientes do escritório (nome, CNPJ único, ramo) |
| `competencias` | um painel por empresa e mês: `periodo` (dia 1), `dados` (jsonb com o estado inteiro, sem a cadeia), `resumo` (números já calculados do mês), `atualizado_em/por` |
| `parceiros` | cadeia de crédito da empresa: tipo, CNPJ, nome, regime, gera crédito, ordem |

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
- `salvar_painel(empresa, período, dados, parceiros, base, resumo)` → grava o mês e a cadeia **numa transação**.
  `base` é o `atualizado_em` de quando o mês foi aberto: se outra pessoa salvou depois, dá `CONFLITO`
  e o painel pergunta se sobrescreve ou abre a versão salva (`'-infinity'` = criar mês que não pode existir).

### Como o painel usa
- Sem login, nenhum dado aparece. A sessão fica guardada e renova sozinha; se cair no meio do
  trabalho, o painel pede o login e **salva o que estava na tela** depois.
- **Primeira empresa:** o que está na tela é salvo nela. **Nova empresa** e **novo mês** começam com
  as categorias e alíquotas (do padrão ou do mês salvo mais próximo) e os valores zerados.
- Trocar de empresa/mês ou sair com alterações pendentes pergunta antes: salvar, descartar ou cancelar.
  Fechar a aba com alterações também avisa.
- A cadeia de crédito é por empresa (vale para todos os meses dela).
- **Excluir um mês:** menu "Opções" → "Excluir *mês* do banco", com janela de confirmação (o botão
  padrão é Cancelar). Apaga a competência para toda a equipe e não dá para desfazer; a cadeia de
  crédito, que é da empresa, não é tocada. Depois abre o mês salvo mais recente — e, se não sobrou
  nenhum, o mês atual **sem gravar**, para não recriar sozinho o que você acabou de apagar. O item
  só aparece quando o mês aberto existe no banco. Usa `DELETE` direto na tabela: o RLS já restringe
  à equipe, não precisou de função nova.
- **Mês novo herda do anterior** (janela "Novo mês", uma caixa por item): o **saldo credor da CBS**
  do mês imediatamente anterior vira o crédito inicial deste, e a **receita dos 12 meses** é somada
  pelos meses salvos. Estoque e valores das despesas gerais são opcionais (vêm desmarcados).
  É **cópia etiquetada, não vínculo vivo**: o número fica gravado no mês e editável, a tela diz de
  onde veio ("veio de jan/2026", "somados 12 de 12 meses salvos") e há um "atualizar" ao lado do
  RBT12 para somar de novo. Nunca herda de mês posterior — saldo credor só anda para a frente.
- **Aba Anual → "O ano pelos meses salvos":** tabela mês a mês (receita, DAS, CBS por fora, resultado,
  margem) com totais, leitura do exercício (alíquota efetiva média, carga, qual regime sairia mais
  barato no acumulado, faixa do Simples, melhor e pior mês), alerta de **sublimite (R$ 3,6 mi)** e de
  **exclusão (R$ 4,8 mi)** pelo ritmo do ano, aviso dos meses sem competência salva e o botão
  "Preencher o exercício com estes meses" (pede confirmação: substitui o que estiver digitado).

### Testes
Não há Postgres nesta máquina: o SQL foi validado com o parser do Postgres 17 (libpg_query) e o
painel foi testado contra um servidor que imita o Supabase (login, REST, RPC, conflito, sessão
expirada). Na primeira instalação real, rode `conferir_instalacao.sql` e faça um salvamento de teste.

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
   (Simples sem CBS + CBS + IBS), no quadro Convencional × Híbrido, fim da aba Resultado.

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
