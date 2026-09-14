-- 005_statuses.sql - Table statuses pour migration P1.3 (identique à Moments)
create table if not exists public.statuses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('text','image')),
  text text,
  media_path text,
  duration_minutes int not null default 1440,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index if not exists idx_statuses_user on public.statuses(user_id, expires_at);
create index if not exists idx_statuses_expires on public.statuses(expires_at);
alter table public.statuses enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='statuses_select_all') then
    create policy statuses_select_all on public.statuses for select using (expires_at > now());
  end if;
  if not exists (select 1 from pg_policies where policyname='statuses_insert_own') then
    create policy statuses_insert_own on public.statuses for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname='statuses_update_own') then
    create policy statuses_update_own on public.statuses for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname='statuses_delete_own') then
    create policy statuses_delete_own on public.statuses for delete using (auth.uid() = user_id);
  end if;
end $$;
-- Consultation seule : aucune policy ne permet à un utilisateur de modifier/supprimer le statut d'autrui
-- (seul le propriétaire via auth.uid() = user_id peut update/delete son propre statut)
do $$ begin alter publication supabase_realtime add table public.statuses; exception when others then null; end $$;
-- Nettoyage expirés (cron via pg_cron si dispo)
-- select cron.schedule('purge-statuses','0 * * * *','delete from public.statuses where expires_at < now()');
