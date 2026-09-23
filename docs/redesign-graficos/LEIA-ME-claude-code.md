# Redesign dos gráficos da DRE — instruções para o Claude Code

Coloque esta pasta dentro do repositório (ex.: `docs/redesign-graficos/`) e peça ao Claude Code:

> Leia `docs/redesign-graficos/LEIA-ME-claude-code.md` e `referencia-graficos.html`. Reimplemente a seção de gráficos da tela da DRE seguindo essa referência, usando os componentes, a stack e os dados reais do projeto. Não copie o HTML literalmente; adapte ao padrão do código existente.

## Arquivos

- `referencia-graficos.html` — referência funcional em HTML + JS puro. Abra no navegador. O objeto `DRE` no topo do script é o **contrato de dados** esperado. Os valores mensais nele são estimativas tiradas do print e devem ser substituídos pelos dados reais.
- `Main.dc.html` — o mesmo design no formato do canvas do Claude. Serve só de consulta visual.

## O que implementar

1. **Seletor de período único (6 / 12 meses)** no topo da seção, controlando os dois gráficos.
2. **Gráfico "Receita e imposto, mês a mês"**
   - Barra empilhada por mês: base = imposto (vermelho `#B5452F`), topo = receita − imposto (verde `#3E8E6A`). A altura total é a receita.
   - Valor da receita em cima de cada barra (`54,3 mil`) e a alíquota do mês logo abaixo (`8,0% imp.`).
   - Eixo Y com escala calculada a partir do maior valor (`niceMax`). **Não fixar o topo.**
   - Meses sem lançamento aparecem como contorno tracejado, com nota explicando que contam como zero.
   - Clique numa barra seleciona o mês. As não selecionadas ficam em tons claros.
   - Painel lateral do mês selecionado: receita, variação vs mês anterior, barra de proporção, imposto + alíquota, "fica com a empresa", folha, Fator R.
3. **Gráfico "Fator R"**
   - Remover o eixo duplo e as barras de faturamento, que já aparecem no gráfico de cima.
   - Linha do Fator R com escala própria (0–32%), linha tracejada no corte de 28% e a faixa acima sombreada como "Anexo III".
   - Folha mensal em mini-barras azuis abaixo, alinhadas coluna a coluna com o gráfico de receita (mesmo `gap`, mesma largura do eixo Y = 52px).
   - Painel lateral: Fator R atual, medidor 0–35% com marca em 28%, folha necessária, folha atual, diferença **com** encargos e o equivalente **sem** encargos, campo de encargos (%) e aviso de meses não salvos.
4. **Responsivo:** abaixo de 900px, o painel lateral desce para baixo do gráfico.
5. **Acessibilidade:** barras são `<button>` com `aria-label` e `aria-pressed`; foco visível; `role="meter"` no medidor.

## Tokens

| Uso | Cor |
|---|---|
| Fundo da página | `#F3F1EC` |
| Card / borda | `#FFFFFF` / `#E4E0D8` |
| Texto / secundário | `#1C1B19` / `#6B665E` |
| Receita (fica com a empresa) | `#3E8E6A` · claro `#B9DBC8` |
| Imposto | `#B5452F` · claro `#E0A698` |
| Folha | `#3B6FB6` · claro `#A9C1E3` |
| Zona Anexo III | `#EEF6F1` |

Fontes: IBM Plex Sans (texto) e IBM Plex Mono (números). Se o projeto já tiver fontes definidas, use as do projeto.

## Bugs encontrados na tela atual (corrigir junto)

1. **Eixo do gráfico de faturamento:** o topo mostra "100 mil" e o meio "80 mil", o que é inconsistente. Pela altura das barras, o topo real é por volta de 160 mil. Calcular a escala dinamicamente.
2. **Card "CBS a pagar":** débito R$ 4.884,15 − crédito R$ 11.841,98 = **−R$ 6.957,83**. É saldo credor, não valor a pagar. Quando o resultado for negativo, mostrar "Crédito de CBS a compensar", sem o destaque vermelho.
3. **"Faltam R$ 54.867,57":** esse valor é a folha que falta **sem** os 8% de encargos. Com encargos, faltam R$ 59.256,97. Deixar explícito qual é qual (a referência mostra os dois).
4. **Anexo contraditório:** o rodapé diz "Anexo I · Comércio", mas o texto do Fator R fala em Anexo V/III. O Fator R só se aplica a atividades dos Anexos III/V. Se a empresa estiver no Anexo I, esconder o bloco do Fator R; senão, corrigir o anexo exibido. Confirmar a regra com o responsável fiscal antes de mudar.
