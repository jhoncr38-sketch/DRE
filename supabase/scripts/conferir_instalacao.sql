-- =============================================================================
-- Conferir se o banco ficou configurado (rode no SQL Editor depois da migração)
-- Esperado: 4 tabelas com rls_ligado = true, 4 políticas e 5 funções
-- (eh_membro, marcar_atualizacao, carregar_painel, salvar_painel, resumos).
-- =============================================================================

select c.relname as tabela, c.relrowsecurity as rls_ligado
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('membros', 'empresas', 'competencias', 'parceiros')
order by 1;

select tablename as tabela, policyname as politica, cmd as operacao, roles as papeis
from pg_policies
where schemaname = 'public'
order by 1, 2;

select p.proname as funcao, p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('eh_membro', 'marcar_atualizacao', 'carregar_painel', 'salvar_painel', 'resumos')
order by 1;

-- coluna do resumo do mês (migração 20260912): deve devolver uma linha
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'competencias' and column_name = 'resumo';

-- a chave pública (anon) não pode ler nenhuma tabela: todas as linhas devem vir "false"
select t.relname as tabela, has_table_privilege('anon', t.oid, 'select') as anon_pode_ler
from pg_class t
join pg_namespace n on n.oid = t.relnamespace
where n.nspname = 'public'
  and t.relname in ('membros', 'empresas', 'competencias', 'parceiros')
order by 1;
