-- 004_contact_requests.sql - Validation mutuelle ajout contact
-- Exécuter dans Supabase Dashboard > SQL Editor

-- Table des demandes d'ajout (scan QR -> validation)
create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references public.profiles(id) on delete cascade,
  to_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique(from_user_id, to_user_id)
);

-- Index pour requêtes entrantes/sortantes
create index if not exists idx_contact_requests_to on public.contact_requests(to_user_id, status);
create index if not exists idx_contact_requests_from on public.contact_requests(from_user_id, status);

-- RLS
alter table public.contact_requests enable row level security;

-- Permettre à l'utilisateur de voir ses demandes envoyées et reçues
do $$ begin
  if not exists (select 1 from pg_policies where policyname='contact_requests_select_own') then
    create policy contact_requests_select_own on public.contact_requests
      for select using (auth.uid() = from_user_id or auth.uid() = to_user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname='contact_requests_insert_own') then
    create policy contact_requests_insert_own on public.contact_requests
      for insert with check (auth.uid() = from_user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname='contact_requests_update_receiver') then
    create policy contact_requests_update_receiver on public.contact_requests
      for update using (auth.uid() = to_user_id or auth.uid() = from_user_id)
      with check (auth.uid() = to_user_id or auth.uid() = from_user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname='contact_requests_delete_own') then
    create policy contact_requests_delete_own on public.contact_requests
      for delete using (auth.uid() = from_user_id or auth.uid() = to_user_id);
  end if;
end $$;

-- Fonction pour accepter une demande (crée l'amitié mutuelle si besoin)
-- Optionnel: si vous avez une table contacts/friends, insérer ici. Sinon la lecture de contact_requests suffit.
create or replace function public.accept_contact_request(req_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if auth.uid() is null then raise exception 'Non authentifié'; end if;
  select * into r from public.contact_requests where id = req_id and to_user_id = auth.uid() and status='pending';
  if not found then raise exception 'Demande introuvable ou déjà traitée'; end if;
  update public.contact_requests set status='accepted', responded_at=now() where id=req_id;
  -- Optionnel: créer aussi la relation inverse pour faciliter les requêtes
  -- On laisse la lecture se faire via (from= A,to=B,accepted) OR (from=B,to=A,accepted)
  return to_jsonb(r);
end;
$$;

grant execute on function public.accept_contact_request(uuid) to authenticated;

-- Realtime (idempotent)
do $$ begin alter publication supabase_realtime add table public.contact_requests; exception when others then null; end $$;
