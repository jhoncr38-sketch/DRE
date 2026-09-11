-- =============================================================================
-- Dar acesso ao painel para uma pessoa da equipe
--
-- 1) Supabase → Authentication → Users → "Add user" → "Create new user"
--    informe e-mail e senha e marque "Auto Confirm User".
-- 2) Troque o e-mail e o nome abaixo e rode no SQL Editor.
--
-- Papel: 'admin' ou 'equipe' (hoje os dois têm o mesmo acesso; fica registrado
-- para quando houver telas só de administrador).
-- =============================================================================

insert into public.membros (user_id, nome, papel)
select u.id, 'Nome da pessoa', 'admin'
from auth.users u
where u.email = 'pessoa@escritorio.com.br'
on conflict (user_id) do update set nome = excluded.nome, papel = excluded.papel;

-- conferir quem tem acesso
select m.nome, u.email, m.papel, m.criado_em
from public.membros m
join auth.users u on u.id = m.user_id
order by m.criado_em;


-- Para tirar o acesso de alguém (os dados salvos continuam):
-- delete from public.membros
-- where user_id = (select id from auth.users where email = 'pessoa@escritorio.com.br');
