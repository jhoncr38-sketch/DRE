# Roteiro — mês novo herdando do anterior + aba Anual pelos meses salvos

> **Situação:** APLICADO em 12/09/2026 (Fases 0 a 3), com testes verdes nas duas suítes.
> A migração `20260912120000_resumo_e_heranca.sql` **já foi aplicada** no Supabase do projeto "dre"
> (conferido: 5 funções, coluna `resumo jsonb`, `salvar_painel` com `p_resumo`, `anon` sem execução).
> Veja "O que foi aplicado", no fim.

Pedido original: ao criar um mês novo para a mesma empresa, trazer informações do mês anterior
(CBS Crédito, RBT12 já calculado) e usar os meses salvos para enriquecer a aba Anual.

## 1. Análise

O mês novo **já herda** estrutura do mês modelo (categorias, alíquotas, anexo, tipos de receita,
regra de crédito de cada despesa) e a cadeia de crédito já é por empresa. Falta a parte **numérica
de continuidade**.

Dois pontos do código trabalham contra hoje:

- `zerarValores()` apaga justamente `rbt12` e `saldoCredorAnterior` (`src/dashboard_template.html`, linha 1458).
- `carregar_painel` devolve como `modelo` o mês **mais próximo**, que pode ser *posterior*
  (`supabase/migrations/20260911120000_estrutura_inicial.sql`, linha 182). Herdar saldo credor de um
  mês futuro seria errado — é preciso o mês **imediatamente anterior**.

Natureza de cada dado (não são todos iguais):

| Dado | Natureza | Como herdar |
|---|---|---|
| **CBS Crédito (saldo credor)** | Continuidade: o saldo de um mês *é* o crédito inicial do seguinte | Do mês imediatamente anterior, nunca do "mais próximo" |
| **RBT12** | Derivado de 12 meses de receita; hoje digitado do PGDAS | Calcular pela série salva, dizendo quantos meses entraram |
| **Estoque final → inicial** | Continuidade, mas as linhas são texto livre | Opcional, com confirmação |
| **Despesas fixas** (aluguel, contabilidade, folha) | Repetição, não continuidade | Opção no modal, nunca automático |

Atenção: o saldo credor da CBS é número de **simulação** (regime híbrido), não crédito que a empresa
tem hoje na Receita. Carregá-lo adiante está certo dentro da simulação e não duplica nada —
`saldoCredor` já é líquido do `saldoAnterior` que entrou (`calcMes`, linhas 649-651) — mas a tela
precisa dizer de onde veio, senão vira número órfão.

## 2. Decisão tomada: cópia etiquetada, não vínculo vivo

- **(A) Cópia no momento da criação, com etiqueta e botão "atualizar"** ← escolhida
- (B) Vínculo vivo, recalculado a cada abertura

Motivo: o modelo do painel é "cada mês é um JSON completo e auditável". Com (B), abrir dezembro
poderia mudar números de janeiro sem ninguém pedir, e o `sujo()` (linha 1538) passaria a acusar
alteração sozinho. Com (A) o número fica gravado no mês, editável, com a origem escrita ao lado
("saldo credor de nov/2025") e um botão para puxar de novo se o mês anterior mudar.

## 3. Gargalo de dados e a solução

RBT12 e a aba Anual precisam ler **vários meses**. Hoje só existe `listarMeses` (só o campo
`periodo`, linha 1646). Baixar o `dados` inteiro de 12 meses é pesado e desnecessário.

**Solução:** coluna `resumo jsonb` em `competencias`, gravada pelo próprio painel no `salvar_painel`
— o cliente já calcula tudo em `calcMes()`, nada de reimplementar imposto em SQL.

```
resumo = {receita, das, cbs, saldoCredor, resultado, carga, rbt12, anexo, faixa, efetiva}
```

Meses antigos ficam com `resumo` nulo → fallback lendo o `dados` daquele mês e reescrevendo o resumo
no próximo salvamento (backfill preguiçoso, sem script de migração de dados).

## 4. Fases

### Fase 0 — banco (nova migração SQL)
- Coluna `resumo jsonb`; `salvar_painel` ganha `p_resumo`.
- `carregar_painel` passa a devolver `anterior` (período + resumo do mês imediatamente anterior:
  `periodo < p_periodo order by periodo desc limit 1`) e `serie` (resumos dos 13 meses anteriores).
- Arquivo **novo** em `supabase/migrations/`, sem tocar no `20260911120000` já aplicado.
- Atualizar `supabase/scripts/conferir_instalacao.sql`.

### Fase 1 — herança no mês novo
Arquivos: `abrirMes` (linha 1652), `novoMes` (linha 1769), `zerarValores` (linha 1451).
- `zerarValores` ganha parâmetro com o que **não** zerar.
- `abrirMes` aplica `anterior.saldoCredor` em `saldoCredorAnterior` e o RBT12 calculado em `monthly.rbt12`.
- Modal "Novo mês" lista o que será herdado, com caixas de seleção (saldo credor / RBT12 / estoque /
  despesas fixas).
- Etiquetas na tela: "saldo credor de nov/2025" no campo do saldo; "somados 12 de 12 meses" — ou
  "7 de 12 — confira no PGDAS" — no RBT12.
- Modo local (sem banco) continua exatamente como hoje.

### Fase 2 — aba Anual pelos meses salvos
Arquivos: `rAnual` (linha 1345), `calcAno` (linha 746).
- Mantém o anual digitado (é o que o contador declara) e **acrescenta** o bloco "O ano pelos meses
  salvos": tabela mês a mês (receita, DAS, CBS híbrida, resultado, margem), botão "preencher o anual
  com estes meses" e aviso de meses faltando — mesmo padrão do aviso "informado × soma das linhas"
  que já existe (linha 993).

### Fase 3 — leitura do ano (gráficos e alertas)
- Evolução do RBT12 com a faixa do Simples mês a mês e **alerta de sublimite (R$ 3,6 mi) e de
  exclusão (R$ 4,8 mi)** com projeção pelo ritmo do ano — a informação de maior valor para o cliente.
- Convencional × Híbrido **acumulado no ano** (qual teria sido mais barato) e saldo credor acumulado.
- Carga tributária e alíquota efetiva média do exercício; melhor e pior mês.

## 5. Testes (a cada fase, antes de qualquer push)
Mock do Supabase em `teste_banco.py` ganha `resumo` / `anterior` / `serie`. Casos novos:
- mês novo herda saldo credor e RBT12 do mês anterior;
- **não** herda de mês posterior;
- série incompleta mostra "N de 12";
- anual consolida os meses salvos e acusa lacuna;
- modo local segue zerando tudo.

## 6. Riscos e bordas já previstos
- Mês anterior **editado depois** → número fica velho: etiqueta + botão "atualizar" (o resumo no
  banco permite detectar a divergência).
- Mês criado **fora de ordem** (janeiro antes de dezembro) → herda só do que existe antes dele.
- Empresa nova / primeiro mês → nada a herdar, tudo zero como hoje.
- RBT12 **nunca** é inventado: ou soma 12 meses, ou diz quantos somou.
- Não exige migração de esquema do estado (v7): as chaves novas são opcionais e o
  `mesclar(defaults(), ...)` já as absorve.

## 7. O que foi aplicado (12/09/2026)

As quatro fases entraram. Diferenças em relação ao que estava planejado:

- **Meses antigos não ficam de fora.** O plano dizia que mês sem `resumo` só mostraria a receita.
  Na prática o painel baixa o estado desses meses (uma requisição só, `periodo=in.(…)`) e recalcula
  na hora com `resumoDe()` — o ano fica completo sem ninguém precisar reabrir e salvar 12 meses.
- **Evolução do RBT12 e da faixa** virou frase na "Leitura do ano" ("a faixa foi da 3ª à 4ª"), em vez
  de gráfico próprio: o dado já está na tabela e um gráfico a mais não pagava o espaço.
- **Compatibilidade com banco sem a migração:** `salvar_painel` é chamado com `p_resumo` e, se o banco
  recusar (PGRST202), o painel salva sem ele e não tenta de novo na sessão (`banco.semResumo`).

Onde está cada coisa, em `src/dashboard_template.html`:

| Peça | Função |
|---|---|
| Resumo do mês | `resumoDe()`, `prontoParaCalculo()`, `comEstado()` |
| Herança | `HERANCA`, `herdarDoAnterior()`, `somarRbt12()`, `atualizarRbt12()`, `zerarValores(base, manter)` |
| Janela do mês novo | `novoMes()` + `caixas` no `modal()` |
| Aba Anual | `carregarAno()`, `garantirAno()`, `totaisAno()`, `mesesFaltando()`, `textoAno()`, `alertaLimite()`, `preencherAno()`, `rAnoMeses()` |

Testes: `teste_banco.py` seções **3b** (herança: saldo credor, RBT12, caixas, nada do futuro,
atualizar), **3c** (aba Anual: lacunas, soma do ano, leitura, preencher) e **3d** (banco sem a
migração continua salvando).
