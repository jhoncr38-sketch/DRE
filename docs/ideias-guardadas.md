# Ideias guardadas — painel DRE

> **Situação:** nada deste documento foi aplicado. Guardado em 16/09/2026 a pedido, para retomar depois.
> Para qualquer item: montar o roteiro, aprovar, testar, ver no navegador e só então aplicar no banco e
> subir para o GitHub (regra do projeto: ver antes de subir).

## Ordem sugerida

1. **IBS calculado + cronograma da transição** — hoje o total do regime híbrido está subestimado (só a CBS é
   calculada). É pré-requisito para decidir migração e para comparar com o Lucro Presumido.
2. **Painel de empresas, versão 1** — ver seção 1.
3. **Cópia diária do banco fora do Supabase** — o projeto não tem backup (conferido em 16/09/2026).

---

## 1. Painel de empresas (tela inicial com todas as empresas)

**Ideia do usuário:** em vez de abrir na última empresa, abrir uma tela com todas as empresas e um mini resultado
do mês de cada uma; clicar abre a DRE de sempre.

**Opinião:** vale. A tela vira o painel de trabalho do escritório e junta três ideias antigas numa peça só
(busca de empresa, visão da carteira, botão Voltar) — reduz poluição em vez de aumentar.

**Base técnica que já existe:** cada mês salvo guarda `resumo` (`resumoDe()`): receita, DAS, Simples, CBS,
resultado, total no híbrido (`naTransicao`), alíquota efetiva, anexo, faixa, RBT12. A lista inteira sai de
**uma consulta**, sem abrir o mês de nenhuma empresa.

**Desenho proposto:**
- **Um mês escolhido para todas** (seletor no topo; padrão = mês que está sendo fechado), não "o último de cada
  uma" — senão mistura meses. Empresa sem aquele mês aparece como **não lançado**: a tela vira o checklist do
  fechamento.
- **Lista em linhas**, não cartões grandes (escala para dezenas de clientes). Busca e filtros: Todas, Pendentes,
  Híbrido ganha.
- **Poucos números:** receita, resultado (margem), Simples (alíquota efetiva), convencional × híbrido (quem ganha
  e a diferença), situação (salvo quando / não lançado).
- **Contadores, não somas:** "14 de 18 lançadas · 3 com híbrido mais barato · 4 pendentes". Somar receita de
  clientes diferentes não significa nada.
- **Clicar abre a empresa no mês escolhido.** "← Empresas" no cabeçalho volta, perguntando se houver alteração
  não salva (a pergunta já existe).

```
Competência: ago/2026 ▾      🔍 buscar empresa        [Todas] [Pendentes] [Híbrido ganha]

14 de 18 lançadas  ·  3 com híbrido mais barato  ·  4 pendentes

EMPRESA              RECEITA      RESULTADO       SIMPLES     CONV. × HÍBRIDO        SITUAÇÃO
BRO                  31.973,21    8.210 (25,7%)   6,03%       híbrido −1.240,00      salvo hoje 08:09
Lia Papelaria        51.872,34    4.905 (9,5%)    4,59%       conv. −380,00          salvo 14/09
C Bezerra Marcenaria     —            —              —              —               não lançado
```

**Cuidados obrigatórios:**
- **Privacidade:** a tela mostra todos os clientes — **não pode aparecer no modo apresentação nem no link do
  cliente**.
- **Botão Voltar do navegador** precisa voltar da DRE para a lista, não sair do sistema.
- Meses salvos antes de 12/09/2026 não têm `resumo`: mostrar só a receita e "abra para atualizar".

**Esforço estimado:** médio (parecido com lixeira + histórico).

| Parte | Esforço |
|---|---|
| Função no banco que devolve os resumos de todas as empresas de um mês | pequeno |
| Tela da lista (mês, busca, filtros, contadores, linhas) | médio |
| Clicar abre no mês; "← Empresas" volta | pequeno |
| Esconder no modo apresentação / link do cliente | pequeno |
| Mudar a porta de entrada (abrir a lista, não a última empresa) — **refaz vários testes com banco** | médio |
| Botão Voltar do navegador (mexe na navegação e no link do cliente, que usa o endereço) | médio, o mais arriscado |

**Versão 1:** lista com mês escolhido, busca, filtro de pendentes, contadores e números; clicar abre; voltar;
esconder na apresentação.
**Versão 2 (só depois de usar):** botão Voltar do navegador, mini tendência da receita (6 meses), coluna de alertas
(sublimite, saldo credor parado, DAS não digitado — este pede guardar o DAS declarado no resumo), ordenar por maior
diferença a favor do híbrido.

---

## 2. Comparar com o Lucro Presumido ("Sair do Simples?")

**Receio do usuário:** poluir o sistema. **Opinião:** vale, com duas condições.

**Por que vale:** com a CBS/IBS, empresa de **serviço que vende para empresas**, com margem alta e pouca folha,
pode pagar menos fora do Simples (crédito integral para ela e para o cliente). Clientes como a BRO ("Serviços de
consultoria em engenharia") têm esse perfil. O painel já tem receita, despesas, compras com crédito e o cálculo
de débito/crédito da CBS.

**O que torna perigoso:**
1. **Sem IBS a comparação sai errada** — o IBS por fora pesa muito no Presumido. Condição nº 1: IBS antes.
2. **Comércio (ICMS, substituição, alíquotas por estado)** não cabe numa simulação honesta; serviço (ISS) cabe.
3. **Folha decide muitas vezes:** no Simples a contribuição patronal costuma estar no DAS; no Presumido são ~20% +
   adicionais sobre a folha. Precisa da folha separada.
4. Regras do Presumido também mudam na transição 2027–2033.

**Como fazer sem poluir:**
- **Não** colocar como terceiro cartão no quadro Convencional × Híbrido.
- **Bloco separado, fechado por padrão** ("Sair do Simples?"), que **só lê** os dados do mês. Premissas próprias
  (presunção, ISS do município, folha) dentro do bloco, com padrão.
- **Primeira versão só para serviços**; em comércio diz "não calculado para comércio".
- Sempre rotulado **estimativa**. Por ser isolado, sai inteiro se não for usado.

**Ordem:** IBS → bloco para serviços → comércio só se houver cliente que precise.
**Teste antes de decidir:** contar quantos clientes são serviço vendendo para empresas.

---

## 3. Análise e escolha

| Ideia | O que faz | Dados | Tamanho |
|---|---|---|---|
| Decisão pelo período da opção | Soma os meses que a opção de recolher por fora vai cobrir e avisa o prazo (datas a confirmar no regulamento do CGSN) | meses salvos + calendário | médio |
| Crédito que o cliente ganha | "No híbrido, seus clientes empresa recuperam R$ X/mês" — argumento de venda | cadeia (clientes que aproveitam crédito) + parte da receita para eles | pequeno |
| O que mais pesa na decisão | Barras ordenadas: cada premissa ±10% e quanto muda a diferença entre regimes — o que conferir primeiro | existentes | médio |
| Perfil para o híbrido | Fatores lado a lado (vendas a empresas, compras com crédito, fornecedores do regime regular, margem, saldo credor) — explicação, não nota | quase todos existentes | pequeno |
| Ponto de equilíbrio | Faturamento mínimo para não ter prejuízo | DRE; separar fixo e variável | pequeno |
| Quanto fica de cada R$ 100 a mais | Lucro da venda adicional após custo, DAS na faixa em que cairia e CBS | DRE + tabela do Simples | pequeno |
| Giro e dias de estoque | Dias até o estoque virar venda; dinheiro parado | bloco Estoque e compras + custo das vendas | pequeno |
| Anexo sugerido pelo CNAE | Sugere o anexo e avisa Fator R (sugestão; a escolha é da pessoa) | tabela oficial CGSN (há PDFs nos Downloads) | médio |

**Mais antigas, ainda válidas:** curva ano a ano até 2033 (em que ano o híbrido passa na frente); Fator R;
alíquota do próximo real (troca de faixa); competência × competência (3 linhas que mais mudaram); saldo credor que
só cresce; custo do fornecedor que não dá crédito (e desconto para empatar); preço de venda com CBS/IBS por fora;
split payment (efeito no caixa); distribuição de lucros isenta; calendário de caixa dos tributos.

**No quadro Convencional × Híbrido:** efeito da diferença no resultado e na margem; acumulado dos meses salvos com
placar; por que a diferença existe (frase de causa); faixa de sensibilidade das alíquotas; selo de conferência com
o PGDAS. (A ressalva "IBS ainda não calculado" já foi aplicada.)

---

## 4. Segurança e operação

Já aplicado em 16/09/2026: lixeira (30 dias), histórico de versões do mês e dos cadastros, trava contra apagar
fornecedores/produtos por lista vazia, empresa nova em branco, sem gravar sozinho. Ideias que ficaram:

- **Cópia diária do banco fora do Supabase** — tarefa agendada gratuita exportando empresas, meses, fornecedores e
  produtos. **Destino privado** (dados financeiros de clientes): nunca num repositório público.
- **Registro de atividade** (Opções → Atividade): quem salvou, excluiu, restaurou ou trocou lista, quando e em qual
  mês. O incidente de 16/09 só foi reconstruído pelo log do Supabase, que dura pouco e exige token.
- **Mês fechado:** depois de entregar ao cliente, o mês fica só leitura; reabrir pede confirmação e fica registrado.
- **Rascunho no navegador:** o que foi digitado e não salvo sobrevive a aba fechada ou internet caída; ao reabrir,
  oferece recuperar. (Não é salvar sozinho no banco — isso continua não recomendado: multiplicaria conflitos.)
- **Aviso de versão nova do painel:** aba aberta roda o código antigo; avisar "recarregue".
- Tela de equipe no painel (convidar/remover sem SQL) e **papéis de verdade** (só admin exclui mês/empresa) — os
  papéis `admin`/`equipe` já estão gravados em `membros`, mas hoje valem igual.
- "Fulano está editando este mês" (hoje o conflito só aparece ao salvar).

## 5. Consultoria e relacionamento

- Anexos do mês (PGDAS, balancete, extrato) guardados na competência.
- Indicadores do ramo: média anônima da carteira (margem, carga, crédito), só com um mínimo de empresas no ramo.
- Metas e alertas por cliente (margem mínima, carga máxima, saldo credor parado).
- Fechamento projetado do exercício (receita, DAS, CBS, resultado, com faixa de incerteza).
- Simulação que não mexe no mês salvo ("e se as compras com crédito subirem 20%?").
- Apresentação em roteiro (blocos em sequência, avançando com as setas).
- Exportar o ano inteiro para Excel (um mês por aba + resumo).
- Modelo por ramo ao criar empresa (contas e regras típicas de farmácia, construção, transporte, advocacia).
- Link de leitura para o cliente; anotações assinadas por competência; PDF de uma página.

## 6. Usabilidade

- **Desfazer** (Ctrl+Z e "Desfazer" no aviso) — hoje o × apaga a linha na hora.
- **Colar do Excel** direto nas tabelas (nome e valor).
- **Erro de digitação na hora**, ao lado do campo ("alíquota 80%? você quis dizer 8%").
- Endereço da página por empresa, mês e aba (favoritos e botão Voltar).
- Não perder o cursor depois de redesenhar a tela.
- Roteiro do mês novo (anexo → receita 12 meses → receita do mês → DAS → despesas, com ✓).
- "?" com explicação curta nos termos (RBT12, parcela 15,33%, saldo credor, cClassTrib).
- Copiar a DRE como tabela para Excel/e-mail.
- Pendências antigas: tabela de produtos rola para o lado no celular; tabelas largas cortadas na impressão.

## 7. Dados de fora do painel

- Ler o extrato do PGDAS-D (receita por anexo, RBT12, DAS declarado).
- Consulta de CNPJ na cadeia (nome e se é Simples/MEI).
- XML das notas de compra (crédito exato por nota e fornecedor).
- Importar balancete e mapear contas uma vez por cliente.
- Catálogo alimentando as linhas de receita.

---

## Tentativas desfeitas (para não repetir o caminho)

**Busca NBS × cClassTrib no catálogo (16/09/2026)** — feita e **desfeita a pedido** ("não gostei"; motivo não
informado — perguntar antes de refazer). O que se aprendeu e vale para uma próxima tentativa:
- Fonte: Anexo VIII oficial (correlação Item LC 116 × NBS × INDOP × cClassTrib, v1.01.00). A aba "tabela geral" tem
  **células mescladas**: repetir o valor de cima associa cClassTrib à NBS errada (no item 01.01, só a NBS
  1.1502.90.00 tem 200043/200044). É preciso expandir as mesclagens.
- **Linhas sem NBS** são opções do **item** (itens 99.03.02 a 99.03.05 não têm NBS; no 12.11 e no 17.09 a linha vem
  antes da primeira NBS). Com as mesclagens expandidas: 208 itens, 731 NBS, 1.513 combinações, 28 cClassTrib.
- A mesma NBS aparece em mais de um item, às vezes com opções diferentes: agrupar por item × NBS.
- **O percentual de redução não está no Anexo VIII** — está na tabela cClassTrib do Informe Técnico 2025.002
  (Portal da NF-e → Documentos → Diversos; pRedIBS/pRedCBS). Nunca preencher percentual de memória.
- `dados-originais/` é ignorado pelo Git (planilhas de cliente); tabela oficial pública iria para uma pasta
  versionada à parte.
- O código daquela tentativa não foi guardado no projeto.
