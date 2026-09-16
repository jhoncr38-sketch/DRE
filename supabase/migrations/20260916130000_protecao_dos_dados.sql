-- =============================================================================
-- Painel DRE — proteção dos dados: lixeira, versões e trava das listas da empresa
-- =============================================================================
-- O que motivou (16/09/2026, reconstruído pelo registro de requisições do Supabase):
--   • seis meses da Consult RL foram excluídos pelo "Excluir mês". O DELETE apagava de vez e o projeto não tem
--     backup — não havia como voltar;
--   • cada salvamento substitui fornecedores, clientes e o catálogo da EMPRESA pelo que está na tela. Uma tela com
--     a lista vazia apagava todos, sem aviso.
--
-- O que muda:
--   1. Lixeira — todo DELETE em competencias guarda o mês em competencias_lixeira por 30 dias. É gatilho: vale para
--      qualquer caminho, inclusive a versão do painel que já está publicada. restaurar_competencia() devolve.
--   2. Versões do mês — todo UPDATE que muda "dados" guarda o estado anterior em competencias_versoes (30 por mês).
--      restaurar_versao() volta; a restauração também vira versão, então dá para desfazer.
--   3. Versões dos cadastros — fornecedores, clientes e catálogo são da empresa, não do mês: cadastros_versoes guarda
--      a lista de antes sempre que um salvamento for trocá-la (30 por empresa). restaurar_cadastros() volta.
--   4. Trava — salvar_painel não apaga a lista de fornecedores/clientes nem o catálogo por chegarem VAZIOS, a não ser
--      com p_apagar_listas = true (o painel só manda isso depois de perguntar). Painel antigo nunca manda: já fica
--      protegido. Lista igual à do banco não é regravada.
--
-- As tabelas novas só aceitam escrita pelas funções desta migração; a equipe só lê.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Listas da empresa num formato único: o que está no banco e o que chega da tela ficam comparáveis
-- (vazio = null, fornecedores/clientes em ordem de tipo e posição, produtos em ordem de posição)
-- ---------------------------------------------------------------------------
create function public.lista_parceiros(p_empresa_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_array(p.tipo, p.cnpj, p.nome, p.regime, p.gera_credito)
                            order by p.tipo, p.ordem), '[]'::jsonb)
  from public.parceiros p
  where p.empresa_id = p_empresa_id;
$$;

create function public.lista_produtos(p_empresa_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_array(pr.nome, pr.tipo, pr.natureza, pr.ncm, pr.nbs, pr.cclasstrib)
                            order by pr.ordem), '[]'::jsonb)
  from public.produtos pr
  where pr.empresa_id = p_empresa_id;
$$;

create function public.normalizar_parceiros(p_lista jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_array(t.item ->> 0,
                                              nullif(t.item ->> 1, ''),
                                              nullif(t.item ->> 2, ''),
                                              nullif(t.item ->> 3, ''),
                                              nullif(t.item ->> 4, ''))
                            order by t.item ->> 0, t.posicao), '[]'::jsonb)
  from jsonb_array_elements(coalesce(p_lista, '[]'::jsonb)) with ordinality as t (item, posicao);
$$;

create function public.normalizar_produtos(p_lista jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_array(nullif(t.item ->> 0, ''),
                                              nullif(t.item ->> 1, ''),
                                              case when (t.item ->> 2) in ('produto', 'servico') then t.item ->> 2 end,
                                              nullif(t.item ->> 3, ''),
                                              nullif(t.item ->> 4, ''),
                                              nullif(t.item ->> 5, ''))
                            order by t.posicao), '[]'::jsonb)
  from jsonb_array_elements(coalesce(p_lista, '[]'::jsonb)) with ordinality as t (item, posicao);
$$;


-- ---------------------------------------------------------------------------
-- Tabelas: lixeira, versões do mês e versões dos cadastros
-- ---------------------------------------------------------------------------
create table public.competencias_lixeira (
  id              uuid primary key default gen_random_uuid(),
  empresa_id      uuid not null,                  -- sem chave estrangeira: o mês fica na lixeira mesmo sem a empresa
  empresa_nome    text,
  periodo         date not null,
  dados           jsonb not null,
  resumo          jsonb,
  versao          integer,
  criado_em       timestamptz,
  atualizado_em   timestamptz,
  atualizado_por  uuid,
  excluido_em     timestamptz not null default clock_timestamp(),
  excluido_por    uuid default auth.uid()
);
create index competencias_lixeira_idx on public.competencias_lixeira (excluido_em desc);

create table public.competencias_versoes (
  id               uuid primary key default gen_random_uuid(),
  empresa_id       uuid not null references public.empresas (id) on delete cascade,
  periodo          date not null,
  dados            jsonb not null,
  resumo           jsonb,
  versao           integer,
  salvo_em         timestamptz,                   -- quando este estado tinha sido gravado
  salvo_por        uuid,
  substituido_em   timestamptz not null default clock_timestamp(),
  substituido_por  uuid default auth.uid()
);
create index competencias_versoes_idx on public.competencias_versoes (empresa_id, periodo, substituido_em desc);

create table public.cadastros_versoes (
  id               uuid primary key default gen_random_uuid(),
  empresa_id       uuid not null references public.empresas (id) on delete cascade,
  parceiros        jsonb not null,                -- fornecedores e clientes, no formato de lista_parceiros()
  produtos         jsonb not null,                -- catálogo, no formato de lista_produtos()
  substituido_em   timestamptz not null default clock_timestamp(),
  substituido_por  uuid default auth.uid()
);
create index cadastros_versoes_idx on public.cadastros_versoes (empresa_id, substituido_em desc);

alter table public.competencias_lixeira enable row level security;
alter table public.competencias_versoes enable row level security;
alter table public.cadastros_versoes    enable row level security;

-- a equipe lê; ninguém grava direto — só as funções desta migração, que rodam como dono das tabelas
create policy "equipe lê a lixeira" on public.competencias_lixeira
  for select to authenticated using ((select public.eh_membro()));
create policy "equipe lê versões dos meses" on public.competencias_versoes
  for select to authenticated using ((select public.eh_membro()));
create policy "equipe lê versões dos cadastros" on public.cadastros_versoes
  for select to authenticated using ((select public.eh_membro()));

revoke all on table public.competencias_lixeira, public.competencias_versoes, public.cadastros_versoes from anon;
revoke insert, update, delete on table public.competencias_lixeira, public.competencias_versoes, public.cadastros_versoes
  from authenticated;


-- ---------------------------------------------------------------------------
-- Gatilhos: todo mês excluído vai para a lixeira; todo mês alterado deixa a versão anterior
-- ---------------------------------------------------------------------------
create function public.competencia_para_lixeira()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.competencias_lixeira
    (empresa_id, empresa_nome, periodo, dados, resumo, versao, criado_em, atualizado_em, atualizado_por)
  values
    (old.empresa_id, (select e.nome from public.empresas e where e.id = old.empresa_id), old.periodo, old.dados,
     old.resumo, old.versao, old.criado_em, old.atualizado_em, old.atualizado_por);
  delete from public.competencias_lixeira l where l.excluido_em < now() - interval '30 days';
  return old;
end;
$$;

create trigger competencias_exclusao
  before delete on public.competencias
  for each row execute function public.competencia_para_lixeira();

create function public.competencia_guardar_versao()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.dados is distinct from new.dados then
    insert into public.competencias_versoes (empresa_id, periodo, dados, resumo, versao, salvo_em, salvo_por)
    values (old.empresa_id, old.periodo, old.dados, old.resumo, old.versao, old.atualizado_em, old.atualizado_por);
    delete from public.competencias_versoes v
    where v.empresa_id = old.empresa_id and v.periodo = old.periodo
      and v.id not in (select v2.id from public.competencias_versoes v2
                       where v2.empresa_id = old.empresa_id and v2.periodo = old.periodo
                       order by v2.substituido_em desc
                       limit 30);
  end if;
  return new;
end;
$$;

create trigger competencias_versao
  before update on public.competencias
  for each row execute function public.competencia_guardar_versao();

-- lista de agora dos cadastros da empresa, antes de ser trocada (30 por empresa)
create function public.guardar_versao_cadastros(p_empresa_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.eh_membro() then
    raise exception 'SEM_ACESSO' using errcode = '42501';
  end if;
  insert into public.cadastros_versoes (empresa_id, parceiros, produtos)
  values (p_empresa_id, public.lista_parceiros(p_empresa_id), public.lista_produtos(p_empresa_id));
  delete from public.cadastros_versoes v
  where v.empresa_id = p_empresa_id
    and v.id not in (select v2.id from public.cadastros_versoes v2
                     where v2.empresa_id = p_empresa_id
                     order by v2.substituido_em desc
                     limit 30);
end;
$$;


-- ---------------------------------------------------------------------------
-- Salvar: mesma função, com a trava das listas e a versão dos cadastros
-- ---------------------------------------------------------------------------
drop function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz, jsonb, jsonb);

create function public.salvar_painel(
  p_empresa_id     uuid,
  p_periodo        date,
  p_dados          jsonb,
  p_parceiros      jsonb default '[]'::jsonb,
  p_base           timestamptz default null,
  p_resumo         jsonb default null,
  p_produtos       jsonb default null,
  p_apagar_listas  boolean default false
)
returns timestamptz
language plpgsql
set search_path = ''
as $$
declare
  v_atual      timestamptz;
  v_salvo      timestamptz;
  v_parc_atual jsonb;
  v_parc_novo  jsonb;
  v_prod_atual jsonb;
  v_prod_novo  jsonb;
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

  -- listas da empresa: como estão no banco e como chegaram da tela, no mesmo formato
  v_parc_atual := public.lista_parceiros(p_empresa_id);
  v_parc_novo  := public.normalizar_parceiros(p_parceiros);
  v_prod_atual := public.lista_produtos(p_empresa_id);
  -- p_produtos nulo = painel antigo, que não envia o catálogo: não mexe
  v_prod_novo  := case when p_produtos is null then null else public.normalizar_produtos(p_produtos) end;

  -- trava: lista vazia na tela não apaga a da empresa, a não ser que o painel tenha perguntado antes
  if not coalesce(p_apagar_listas, false) then
    if jsonb_array_length(v_parc_novo) = 0 and jsonb_array_length(v_parc_atual) > 0 then
      v_parc_novo := v_parc_atual;
    end if;
    if v_prod_novo is not null and jsonb_array_length(v_prod_novo) = 0 and jsonb_array_length(v_prod_atual) > 0 then
      v_prod_novo := null;
    end if;
  end if;

  -- alguma lista vai mudar e havia o que perder: a de agora fica guardada antes
  if (jsonb_array_length(v_parc_atual) > 0 or jsonb_array_length(v_prod_atual) > 0)
     and (v_parc_novo is distinct from v_parc_atual
          or (v_prod_novo is not null and v_prod_novo is distinct from v_prod_atual)) then
    perform public.guardar_versao_cadastros(p_empresa_id);
  end if;

  if v_parc_novo is distinct from v_parc_atual then
    delete from public.parceiros p where p.empresa_id = p_empresa_id;
    insert into public.parceiros (empresa_id, tipo, cnpj, nome, regime, gera_credito, ordem)
    select p_empresa_id, t.item ->> 0, t.item ->> 1, t.item ->> 2, t.item ->> 3, t.item ->> 4, (t.posicao - 1)::integer
    from jsonb_array_elements(v_parc_novo) with ordinality as t (item, posicao);
  end if;

  if v_prod_novo is not null and v_prod_novo is distinct from v_prod_atual then
    delete from public.produtos pr where pr.empresa_id = p_empresa_id;
    insert into public.produtos (empresa_id, nome, tipo, natureza, ncm, nbs, cclasstrib, ordem)
    select p_empresa_id, t.item ->> 0, t.item ->> 1, t.item ->> 2, t.item ->> 3, t.item ->> 4, t.item ->> 5,
           (t.posicao - 1)::integer
    from jsonb_array_elements(v_prod_novo) with ordinality as t (item, posicao);
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
-- Lixeira e versões: listar e restaurar
-- ---------------------------------------------------------------------------
create function public.listar_lixeira()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.eh_membro() then
    raise exception 'SEM_ACESSO' using errcode = '42501';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', l.id, 'empresa_id', l.empresa_id, 'empresa', coalesce(e.nome, l.empresa_nome),
             'periodo', l.periodo, 'excluido_em', l.excluido_em, 'por', u.email,
             'receita', l.dados -> 'monthly' -> 'receita',
             'sem_empresa', e.id is null,
             'ocupado', exists (select 1 from public.competencias c
                                where c.empresa_id = l.empresa_id and c.periodo = l.periodo))
           order by l.excluido_em desc), '[]'::jsonb)
    from public.competencias_lixeira l
    left join public.empresas e on e.id = l.empresa_id
    left join auth.users u on u.id = l.excluido_por
    where l.excluido_em >= now() - interval '30 days'
  );
end;
$$;

create function public.restaurar_competencia(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.competencias_lixeira%rowtype;
begin
  if not public.eh_membro() then
    raise exception 'SEM_ACESSO' using errcode = '42501';
  end if;
  select * into v_item from public.competencias_lixeira l where l.id = p_id for update;
  if not found then
    raise exception 'NAO_ENCONTRADO' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.empresas e where e.id = v_item.empresa_id) then
    raise exception 'SEM_EMPRESA' using errcode = 'P0001';
  end if;
  -- não passa por cima de um mês que foi criado de novo no mesmo período
  if exists (select 1 from public.competencias c where c.empresa_id = v_item.empresa_id and c.periodo = v_item.periodo) then
    raise exception 'OCUPADO' using errcode = 'P0001';
  end if;
  insert into public.competencias (empresa_id, periodo, dados, versao, resumo)
  values (v_item.empresa_id, v_item.periodo, v_item.dados, coalesce(v_item.versao, 1), v_item.resumo);
  delete from public.competencias_lixeira l where l.id = p_id;
  return jsonb_build_object('empresa_id', v_item.empresa_id, 'periodo', v_item.periodo);
end;
$$;

create function public.listar_versoes(p_empresa_id uuid, p_periodo date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.eh_membro() then
    raise exception 'SEM_ACESSO' using errcode = '42501';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', v.id, 'salvo_em', v.salvo_em, 'salvo_por', us.email,
             'substituido_em', v.substituido_em, 'substituido_por', ur.email,
             'receita', v.dados -> 'monthly' -> 'receita', 'empresa', v.dados ->> 'co')
           order by v.substituido_em desc), '[]'::jsonb)
    from public.competencias_versoes v
    left join auth.users us on us.id = v.salvo_por
    left join auth.users ur on ur.id = v.substituido_por
    where v.empresa_id = p_empresa_id and v.periodo = p_periodo
  );
end;
$$;

create function public.restaurar_versao(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ver public.competencias_versoes%rowtype;
begin
  if not public.eh_membro() then
    raise exception 'SEM_ACESSO' using errcode = '42501';
  end if;
  select * into v_ver from public.competencias_versoes v where v.id = p_id;
  if not found then
    raise exception 'NAO_ENCONTRADO' using errcode = 'P0002';
  end if;
  -- o estado de agora vira versão pelo gatilho: restaurar também se desfaz
  update public.competencias c
  set dados = v_ver.dados, resumo = v_ver.resumo, versao = coalesce(v_ver.versao, c.versao)
  where c.empresa_id = v_ver.empresa_id and c.periodo = v_ver.periodo;
  if not found then
    insert into public.competencias (empresa_id, periodo, dados, versao, resumo)
    values (v_ver.empresa_id, v_ver.periodo, v_ver.dados, coalesce(v_ver.versao, 1), v_ver.resumo);
  end if;
  return jsonb_build_object('empresa_id', v_ver.empresa_id, 'periodo', v_ver.periodo);
end;
$$;

create function public.listar_versoes_cadastros(p_empresa_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.eh_membro() then
    raise exception 'SEM_ACESSO' using errcode = '42501';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', v.id, 'substituido_em', v.substituido_em, 'por', u.email,
             'fornecedores', (select count(*) from jsonb_array_elements(v.parceiros) x where x ->> 0 = 'fornecedor'),
             'clientes', (select count(*) from jsonb_array_elements(v.parceiros) x where x ->> 0 = 'cliente'),
             'produtos', jsonb_array_length(v.produtos))
           order by v.substituido_em desc), '[]'::jsonb)
    from public.cadastros_versoes v
    left join auth.users u on u.id = v.substituido_por
    where v.empresa_id = p_empresa_id
  );
end;
$$;

create function public.restaurar_cadastros(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ver public.cadastros_versoes%rowtype;
begin
  if not public.eh_membro() then
    raise exception 'SEM_ACESSO' using errcode = '42501';
  end if;
  select * into v_ver from public.cadastros_versoes v where v.id = p_id;
  if not found then
    raise exception 'NAO_ENCONTRADO' using errcode = 'P0002';
  end if;
  -- a lista de agora também fica guardada: restaurar se desfaz
  perform public.guardar_versao_cadastros(v_ver.empresa_id);
  delete from public.parceiros p where p.empresa_id = v_ver.empresa_id;
  insert into public.parceiros (empresa_id, tipo, cnpj, nome, regime, gera_credito, ordem)
  select v_ver.empresa_id, t.item ->> 0, t.item ->> 1, t.item ->> 2, t.item ->> 3, t.item ->> 4, (t.posicao - 1)::integer
  from jsonb_array_elements(v_ver.parceiros) with ordinality as t (item, posicao);
  delete from public.produtos pr where pr.empresa_id = v_ver.empresa_id;
  insert into public.produtos (empresa_id, nome, tipo, natureza, ncm, nbs, cclasstrib, ordem)
  select v_ver.empresa_id, t.item ->> 0, t.item ->> 1, t.item ->> 2, t.item ->> 3, t.item ->> 4, t.item ->> 5,
         (t.posicao - 1)::integer
  from jsonb_array_elements(v_ver.produtos) with ordinality as t (item, posicao);
  return jsonb_build_object('empresa_id', v_ver.empresa_id,
                            'parceiros', jsonb_array_length(v_ver.parceiros), 'produtos', jsonb_array_length(v_ver.produtos));
end;
$$;


-- ---------------------------------------------------------------------------
-- Permissões: só usuários logados executam; gatilhos não são chamados direto por ninguém
-- ---------------------------------------------------------------------------
revoke all on function public.competencia_para_lixeira() from public, anon, authenticated;
revoke all on function public.competencia_guardar_versao() from public, anon, authenticated;

revoke all on function public.lista_parceiros(uuid) from public, anon;
revoke all on function public.lista_produtos(uuid) from public, anon;
revoke all on function public.normalizar_parceiros(jsonb) from public, anon;
revoke all on function public.normalizar_produtos(jsonb) from public, anon;
revoke all on function public.guardar_versao_cadastros(uuid) from public, anon;
revoke all on function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz, jsonb, jsonb, boolean) from public, anon;
revoke all on function public.listar_lixeira() from public, anon;
revoke all on function public.restaurar_competencia(uuid) from public, anon;
revoke all on function public.listar_versoes(uuid, date) from public, anon;
revoke all on function public.restaurar_versao(uuid) from public, anon;
revoke all on function public.listar_versoes_cadastros(uuid) from public, anon;
revoke all on function public.restaurar_cadastros(uuid) from public, anon;

grant execute on function public.lista_parceiros(uuid) to authenticated;
grant execute on function public.lista_produtos(uuid) to authenticated;
grant execute on function public.normalizar_parceiros(jsonb) to authenticated;
grant execute on function public.normalizar_produtos(jsonb) to authenticated;
grant execute on function public.guardar_versao_cadastros(uuid) to authenticated;
grant execute on function public.salvar_painel(uuid, date, jsonb, jsonb, timestamptz, jsonb, jsonb, boolean) to authenticated;
grant execute on function public.listar_lixeira() to authenticated;
grant execute on function public.restaurar_competencia(uuid) to authenticated;
grant execute on function public.listar_versoes(uuid, date) to authenticated;
grant execute on function public.restaurar_versao(uuid) to authenticated;
grant execute on function public.listar_versoes_cadastros(uuid) to authenticated;
grant execute on function public.restaurar_cadastros(uuid) to authenticated;
