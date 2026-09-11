-- =============================================================================
-- Painel DRE — estrutura inicial do banco (Supabase / Postgres)
--
-- Como aplicar (escolha um):
--   • Supabase → SQL Editor → cole este arquivo inteiro → Run
--   • CLI: npx supabase init  →  npx supabase link --project-ref <ref>  →  npx supabase db push
--
-- Tabelas:
--   membros       quem da equipe acessa o painel (ligado ao login do Supabase Auth)
--   empresas      clientes do escritório
--   competencias  um painel salvo por empresa e mês (estado completo do painel em JSON)
--   parceiros     cadeia de crédito da empresa: fornecedores e clientes
--
-- Segurança: RLS ligado em todas as tabelas. Só quem está logado E cadastrado em
-- "membros" lê ou grava. A chave pública (anon/publishable) sozinha não acessa nada.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Membros da equipe
-- ---------------------------------------------------------------------------
create table public.membros (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  nome       text,
  papel      text not null default 'equipe' check (papel in ('admin', 'equipe')),
  criado_em  timestamptz not null default now()
);

comment on table public.membros is
  'Equipe com acesso ao painel. Para incluir alguém, use supabase/scripts/adicionar_membro.sql.';

-- "O usuário logado é da equipe?" — usada em todas as políticas.
-- security definer: consulta membros sem passar pela política da própria tabela (evita recursão).
create function public.eh_membro()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.membros m where m.user_id = (select auth.uid())
  );
$$;


-- ---------------------------------------------------------------------------
-- Empresas (clientes do escritório)
-- ---------------------------------------------------------------------------
create table public.empresas (
  id              uuid primary key default gen_random_uuid(),
  nome            text not null check (length(trim(nome)) > 0),
  -- só letras maiúsculas e dígitos, sem pontuação (aceita o CNPJ alfanumérico)
  cnpj            text unique check (cnpj is null or cnpj ~ '^[0-9A-Z]{12}[0-9]{2}$'),
  ramo            text,
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),
  atualizado_por  uuid default auth.uid() references auth.users (id) on delete set null
);


-- ---------------------------------------------------------------------------
-- Competências: um painel por empresa e mês
-- ---------------------------------------------------------------------------
create table public.competencias (
  id              uuid primary key default gen_random_uuid(),
  empresa_id      uuid not null references public.empresas (id) on delete cascade,
  periodo         date not null check (extract(day from periodo) = 1),   -- sempre o dia 1 do mês
  dados           jsonb not null default '{}'::jsonb,                   -- estado do painel (DRE, reforma, estoque...)
  versao          integer not null default 1,                           -- versão do formato de "dados"
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),
  atualizado_por  uuid default auth.uid() references auth.users (id) on delete set null,
  unique (empresa_id, periodo)
);


-- ---------------------------------------------------------------------------
-- Parceiros: cadeia de crédito (fornecedores e clientes da empresa)
-- ---------------------------------------------------------------------------
create table public.parceiros (
  id              uuid primary key default gen_random_uuid(),
  empresa_id      uuid not null references public.empresas (id) on delete cascade,
  tipo            text not null check (tipo in ('fornecedor', 'cliente')),
  cnpj            text check (cnpj is null or cnpj ~ '^[0-9A-Z]{1,14}$'),  -- pode estar incompleto
  nome            text,
  regime          text,
  gera_credito    text check (gera_credito in ('sim', 'parcial', 'nao')),  -- vazio = a definir
  ordem           integer not null default 0,
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),
  atualizado_por  uuid default auth.uid() references auth.users (id) on delete set null
);

create index parceiros_empresa_idx on public.parceiros (empresa_id, tipo, ordem);
create index parceiros_cnpj_idx on public.parceiros (cnpj);


-- ---------------------------------------------------------------------------
-- Data e autor da última alteração
-- ---------------------------------------------------------------------------
create function public.marcar_atualizacao()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.atualizado_em := now();
  new.atualizado_por := (select auth.uid());
  return new;
end;
$$;

create trigger empresas_atualizacao
  before update on public.empresas
  for each row execute function public.marcar_atualizacao();

create trigger competencias_atualizacao
  before update on public.competencias
  for each row execute function public.marcar_atualizacao();

create trigger parceiros_atualizacao
  before update on public.parceiros
  for each row execute function public.marcar_atualizacao();


-- ---------------------------------------------------------------------------
-- Segurança (RLS): só a equipe
-- ---------------------------------------------------------------------------
alter table public.membros      enable row level security;
alter table public.empresas     enable row level security;
alter table public.competencias enable row level security;
alter table public.parceiros    enable row level security;

-- a equipe vê quem é da equipe; incluir ou remover membros só pelo SQL Editor
create policy "equipe lê membros" on public.membros
  for select to authenticated
  using ((select public.eh_membro()));

create policy "equipe acessa empresas" on public.empresas
  for all to authenticated
  using ((select public.eh_membro()))
  with check ((select public.eh_membro()));

create policy "equipe acessa competências" on public.competencias
  for all to authenticated
  using ((select public.eh_membro()))
  with check ((select public.eh_membro()));

create policy "equipe acessa parceiros" on public.parceiros
  for all to authenticated
  using ((select public.eh_membro()))
  with check ((select public.eh_membro()));

-- sem login, nada: tira da chave pública qualquer acesso direto às tabelas
revoke all on table public.membros, public.empresas, public.competencias, public.parceiros from anon;


-- ---------------------------------------------------------------------------
-- Carregar o painel de um mês
--   competencia: o mês salvo (ou null se ainda não existe)
--   modelo:      o mês salvo mais próximo, para começar um mês novo com as mesmas categorias
--   parceiros:   a cadeia de crédito da empresa
-- ---------------------------------------------------------------------------
create function public.carregar_painel(p_empresa_id uuid, p_periodo date)
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
    'parceiros', coalesce((
      select jsonb_agg(jsonb_build_array(p.tipo, p.cnpj, p.nome, p.regime, p.gera_credito)
                       order by p.tipo, p.ordem)
      from public.parceiros p
      where p.empresa_id = p_empresa_id
    ), '[]'::jsonb)
  );
$$;


-- ---------------------------------------------------------------------------
-- Salvar o painel de um mês — tudo numa transação
--   p_base: "atualizado_em" de quando o mês foi aberto na tela.
--           Se alguém salvou depois disso, dá erro CONFLITO (nada é sobrescrito).
--           '-infinity' = o mês ainda não pode existir (criação); null = sobrescrever.
-- ---------------------------------------------------------------------------
create function public.salvar_painel(
  p_empresa_id uuid,
  p_periodo    date,
  p_dados      jsonb,
  p_parceiros  jsonb default '[]'::jsonb,
  p_base       timestamptz default null
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

  insert into public.competencias as c (empresa_id, periodo, dados, versao)
  values (p_empresa_id, p_periodo, p_dados, coalesce((p_dados ->> 'v')::integer, 1))
  on conflict (empresa_id, periodo)
  do update set dados = excluded.dados, versao = excluded.versao
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
-- Permissões das funções: só usuários logados (a segurança real está no RLS)
-- ---------------------------------------------------------------------------
revoke all on function public.eh_membro() from public, anon;
revoke all on function public.marcar_atualizacao() from public, anon;
revoke all on function public.carregar_painel(uuid, date) from public, anon;
revoke all on function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz) from public, anon;

grant execute on function public.eh_membro() to authenticated;
grant execute on function public.carregar_painel(uuid, date) to authenticated;
grant execute on function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz) to authenticated;
