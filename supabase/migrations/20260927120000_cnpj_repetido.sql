-- =============================================================================
-- CNPJ repetido entre empresas
--
-- A tabela nasceu com "cnpj text unique": um CNPJ, uma empresa. Na prática o
-- escritório mantém cenários da mesma empresa lado a lado — "BRO" e "BRO SEM
-- PRO-LABORE" são o mesmo CNPJ com pró-labore diferente — e a cópia de empresa
-- (Opções → Copiar empresa) existe justamente para isso.
--
-- O CNPJ continua obrigatório e continua conferido no formato: ele é o que
-- separa compra de venda na leitura dos XML. O que sai é só a unicidade.
--
-- Depois desta migração, duas empresas podem ter o mesmo CNPJ. A importação não
-- se confunde: ela lê as notas da empresa que está aberta.
-- =============================================================================

alter table public.empresas drop constraint if exists empresas_cnpj_key;

-- o índice continua, sem unicidade: é ele que faz a busca por CNPJ ser rápida
create index if not exists empresas_cnpj_idx on public.empresas (cnpj);
