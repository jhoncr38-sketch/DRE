-- =============================================================================
-- Painel DRE — resumo do mês e herança entre competências
--
-- Como aplicar (escolha um):
--   • Supabase → SQL Editor → cole este arquivo inteiro → Run
--   • CLI: npx supabase db push
--
-- O que muda:
--   • competencias.resumo   números do mês já calculados pelo painel
--   • carregar_painel       passa a devolver "anterior" (o mês imediatamente anterior)
--   • salvar_painel         passa a gravar o resumo (parâmetro novo, opcional)
--   • resumos               lista os meses de um intervalo, sem baixar o estado inteiro
--
-- Enquanto esta migração não for aplicada, o painel continua funcionando: os
-- campos novos chegam vazios e a herança simplesmente não acontece.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Resumo do mês
-- ---------------------------------------------------------------------------
alter table public.competencias add column if not exists resumo jsonb;

comment on column public.competencias.resumo is
  'Números do mês calculados pelo painel: {receita, das, simples, cbs, saldoCredor, resultado, trib, naTransicao, efetiva, rbt12, anexo, faixa}. Nulo nos meses salvos antes desta versão — o painel recalcula a partir de "dados" quando precisa.';


-- ---------------------------------------------------------------------------
-- Carregar o painel de um mês
--   competencia: o mês salvo (ou null se ainda não existe)
--   modelo:      o mês salvo mais próximo, para começar um mês novo com as mesmas categorias
--   anterior:    o mês imediatamente ANTERIOR — origem do saldo credor e do RBT12.
--                Nunca é um mês posterior: saldo credor só anda para a frente.
--                Vem com "dados" apenas quando ainda não tem resumo gravado.
--   parceiros:   a cadeia de crédito da empresa
-- ---------------------------------------------------------------------------
create or replace function public.carregar_painel(p_empresa_id uuid, p_periodo date)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'competencia', (
      select jsonb_build_object('dados', c.dados, 'atualizado_em', c.atualizado_em)
      from public.competencias c
      where c.empresa_id = p_empresa_id and c.periodo = p_periodo
    ),
    'modelo', (
      select c.dados
      from public.competencias c
      where c.empresa_id = p_empresa_id and c.periodo <> p_periodo
      -- primeiro o mês anterior mais recente; se não houver, o seguinte mais próximo
      order by (c.periodo > p_periodo), abs(c.periodo - p_periodo)
      limit 1
    ),
    'anterior', (
      select jsonb_build_object(
               'periodo', c.periodo,
               'resumo', c.resumo,
               'dados', case when c.resumo is null then c.dados else null end)
      from public.competencias c
      where c.empresa_id = p_empresa_id and c.periodo < p_periodo
      order by c.periodo desc
      limit 1
    ),
    'parceiros', coalesce((
      select jsonb_agg(jsonb_build_array(p.tipo, p.cnpj, p.nome, p.regime, p.gera_credito)
                       order by p.tipo, p.ordem)
      from public.parceiros p
      where p.empresa_id = p_empresa_id
    ), '[]'::jsonb)
  );
$$;


-- ---------------------------------------------------------------------------
-- Resumos de um intervalo de meses
--   Usado pelo RBT12 (12 meses anteriores) e pela aba Anual (o exercício).
--   "receita" sai do resumo quando existe e, senão, do próprio estado salvo —
--   assim o RBT12 funciona mesmo em meses gravados antes desta migração.
-- ---------------------------------------------------------------------------
create function public.resumos(p_empresa_id uuid, p_de date, p_ate date)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(t.linha order by t.linha ->> 'periodo'), '[]'::jsonb)
  from (
    select jsonb_build_object(
             'periodo', c.periodo,
             'resumo', c.resumo,
             'receita', coalesce(
               nullif(c.resumo ->> 'receita', '')::numeric,
               nullif(c.dados -> 'monthly' ->> 'receita', '')::numeric, 0)) as linha
    from public.competencias c
    where c.empresa_id = p_empresa_id and c.periodo >= p_de and c.periodo <= p_ate
  ) t;
$$;


-- ---------------------------------------------------------------------------
-- Salvar o painel de um mês — agora gravando também o resumo
--   p_resumo é opcional: sem ele, o mês fica sem resumo (e o painel recalcula
--   a partir de "dados" quando precisar).
-- ---------------------------------------------------------------------------
drop function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz);

create function public.salvar_painel(
  p_empresa_id uuid,
  p_periodo    date,
  p_dados      jsonb,
  p_parceiros  jsonb default '[]'::jsonb,
  p_base       timestamptz default null,
  p_resumo     jsonb default null
)
returns timestamptz
language plpgsql
set search_path = ''
as $$
declare
  v_atual timestamptz;
  v_salvo timestamptz;
begin
  if not public.eh_membro() then
    raise exception 'SEM_ACESSO' using errcode = '42501';
  end if;

  select c.atualizado_em into v_atual
  from public.competencias c
  where c.empresa_id = p_empresa_id and c.periodo = p_periodo
  for update;

  if p_base is not null and v_atual is not null
     and (p_base = '-infinity'::timestamptz or v_atual > p_base) then
    raise exception 'CONFLITO' using errcode = 'P0001', detail = v_atual::text;
  end if;

  insert into public.competencias as c (empresa_id, periodo, dados, versao, resumo)
  values (p_empresa_id, p_periodo, p_dados, coalesce((p_dados ->> 'v')::integer, 1), p_resumo)
  on conflict (empresa_id, periodo)
  do update set dados = excluded.dados, versao = excluded.versao, resumo = excluded.resumo
  returning c.atualizado_em into v_salvo;

  -- cadeia de crédito: a lista enviada substitui a da empresa
  delete from public.parceiros p where p.empresa_id = p_empresa_id;

  insert into public.parceiros (empresa_id, tipo, cnpj, nome, regime, gera_credito, ordem)
  select p_empresa_id,
         t.item ->> 0,
         nullif(t.item ->> 1, ''),
         nullif(t.item ->> 2, ''),
         nullif(t.item ->> 3, ''),
         nullif(t.item ->> 4, ''),
         (t.posicao - 1)::integer
  from jsonb_array_elements(coalesce(p_parceiros, '[]'::jsonb)) with ordinality as t (item, posicao);

  -- o nome digitado no painel vale para a empresa
  update public.empresas e
  set nome = trim(p_dados ->> 'co')
  where e.id = p_empresa_id
    and coalesce(trim(p_dados ->> 'co'), '') <> ''
    and e.nome is distinct from trim(p_dados ->> 'co');

  return v_salvo;
end;
$$;


-- ---------------------------------------------------------------------------
-- Permissões: só usuários logados (a segurança real está no RLS)
-- ---------------------------------------------------------------------------
revoke all on function public.resumos(uuid, date, date) from public, anon;
revoke all on function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz, jsonb) from public, anon;

grant execute on function public.resumos(uuid, date, date) to authenticated;
grant execute on function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz, jsonb) to authenticated;
