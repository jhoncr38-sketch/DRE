-- ---------------------------------------------------------------------------
-- Fator R por empresa
--   O cartão do Fator R na Visão geral não serve a todo mundo: ele só faz
--   sentido em quem vive de serviço (anexos III a V) e é acompanhado de perto.
--   A marca fica na empresa, não na competência, porque a decisão é do
--   escritório sobre o cliente — não muda de mês para mês.
--   O painel funciona sem esta coluna: sem ela, a marca vale só no navegador
--   de quem ligou. Rodar esta migração é o que faz a marca valer para a equipe.
-- ---------------------------------------------------------------------------
alter table public.empresas add column if not exists fator_r boolean not null default false;
