-- =============================================================================
-- Painel DRE — produtos e serviços por empresa (não por mês)
--
-- Como aplicar (escolha um):
--   • Supabase → SQL Editor → cole este arquivo inteiro → Run
--   • CLI: npx supabase db push
--
-- O catálogo do que a empresa vende é cadastro da empresa, como a cadeia de
-- crédito: quem foi cadastrado em agosto tem que aparecer em junho. Até aqui ele
-- ficava dentro do estado de cada competência, e só existia no mês em que foi
-- digitado (ou nos seguintes, por herança).
--
-- O que muda:
--   • tabela produtos      um catálogo por empresa
--   • carregar_painel      passa a devolver "produtos"
--   • salvar_painel        ganha p_produtos (a lista enviada substitui a da empresa)
--   • backfill             traz o que já estava salvo na competência mais recente
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Produtos e serviços da empresa
-- ---------------------------------------------------------------------------
create table public.produtos (
  id              uuid primary key default gen_random_uuid(),
  empresa_id      uuid not null references public.empresas (id) on delete cascade,
  nome            text,
  -- alíquota da CBS: geral | red30 | reduzida | red70 | zero
  tipo            text,
  natureza        text check (natureza is null or natureza in ('produto', 'servico')),
  ncm             text,
  nbs             text,
  cclasstrib      text,
  ordem           integer not null default 0,
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),
  atualizado_por  uuid default auth.uid() references auth.users (id) on delete set null
);

create index produtos_empresa_idx on public.produtos (empresa_id, ordem);

create trigger produtos_atualizacao
  before update on public.produtos
  for each row execute function public.marcar_atualizacao();

alter table public.produtos enable row level security;

create policy "equipe acessa produtos" on public.produtos
  for all to authenticated
  using ((select public.eh_membro()))
  with check ((select public.eh_membro()));

revoke all on table public.produtos from anon;


-- ---------------------------------------------------------------------------
-- Backfill: o catálogo que já estava dentro da competência mais recente de cada
-- empresa vira o catálogo da empresa. Roda uma vez; competências sem produtos
-- simplesmente não geram linha.
-- ---------------------------------------------------------------------------
insert into public.produtos (empresa_id, nome, tipo, natureza, ncm, nbs, cclasstrib, ordem)
select u.empresa_id,
       nullif(t.item ->> 0, ''),
       nullif(t.item ->> 1, ''),
       case when (t.item ->> 2) in ('produto', 'servico') then t.item ->> 2 end,
       nullif(t.item ->> 3, ''),
       nullif(t.item ->> 4, ''),
       nullif(t.item ->> 5, ''),
       (t.posicao - 1)::integer
from (
  select distinct on (c.empresa_id) c.empresa_id, c.dados
  from public.competencias c
  where jsonb_typeof(c.dados -> 'produtos') = 'array'
    and jsonb_array_length(c.dados -> 'produtos') > 0
  order by c.empresa_id, c.periodo desc
) u,
lateral jsonb_array_elements(u.dados -> 'produtos') with ordinality as t (item, posicao);


-- ---------------------------------------------------------------------------
-- Carregar o painel de um mês — agora com o catálogo da empresa
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
    ), '[]'::jsonb),
    'produtos', coalesce((
      select jsonb_agg(jsonb_build_array(pr.nome, pr.tipo, pr.natureza, pr.ncm, pr.nbs, pr.cclasstrib)
                       order by pr.ordem)
      from public.produtos pr
      where pr.empresa_id = p_empresa_id
    ), '[]'::jsonb)
  );
$$;


-- ---------------------------------------------------------------------------
-- Salvar o painel de um mês — agora gravando também o catálogo
-- ---------------------------------------------------------------------------
drop function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz, jsonb);

create function public.salvar_painel(
  p_empresa_id uuid,
  p_periodo    date,
  p_dados      jsonb,
  p_parceiros  jsonb default '[]'::jsonb,
  p_base       timestamptz default null,
  p_resumo     jsonb default null,
  p_produtos   jsonb default null
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

  -- catálogo: idem. p_produtos nulo = painel antigo, que não envia o catálogo — nesse caso não mexe
  if p_produtos is not null then
    delete from public.produtos pr where pr.empresa_id = p_empresa_id;

    insert into public.produtos (empresa_id, nome, tipo, natureza, ncm, nbs, cclasstrib, ordem)
    select p_empresa_id,
           nullif(t.item ->> 0, ''),
           nullif(t.item ->> 1, ''),
           case when (t.item ->> 2) in ('produto', 'servico') then t.item ->> 2 end,
           nullif(t.item ->> 3, ''),
           nullif(t.item ->> 4, ''),
           nullif(t.item ->> 5, ''),
           (t.posicao - 1)::integer
    from jsonb_array_elements(p_produtos) with ordinality as t (item, posicao);
  end if;

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
revoke all on function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz, jsonb, jsonb) from public, anon;
grant execute on function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz, jsonb, jsonb) to authenticated;
