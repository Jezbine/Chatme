-- =============================================================================
-- ChatMe — Script SQL Consolidé de Résolution Complète des Erreurs
-- Copiez-collez l'intégralité de ce script dans Supabase Dashboard > SQL Editor
-- puis cliquez sur "RUN"
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. CORRECTION DU BUG "mark_messages_as_read" (Erreur 42702 + 42P13 rename)
-- -----------------------------------------------------------------------------
drop function if exists public.mark_messages_as_read(uuid,uuid);
create function public.mark_messages_as_read(p_conversation_id uuid, p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then 
    raise exception 'Non authentifié'; 
  end if;

  -- Mettre à jour last_read_message_id pour ce participant
  update public.conversation_participants
  set last_read_message_id = p_message_id
  where conversation_participants.conversation_id = p_conversation_id
    and conversation_participants.user_id = v_user_id;

  -- Marquer les messages comme lus
  update public.messages
  set status = 'read'
  where messages.conversation_id = p_conversation_id
    and messages.sender_id != v_user_id
    and messages.created_at <= (select created_at from public.messages where id = p_message_id)
    and messages.status != 'read';
end;
$$;

grant execute on function public.mark_messages_as_read(uuid, uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- 2. CRÉATION DU BUCKET STORAGE "chat-media" (Vocaux, Images, Pièces jointes)
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', true)
on conflict (id) do update set public = true;

-- Politiques de sécurité Storage pour chat-media
do $$ begin
  if not exists (select 1 from pg_policies where policyname='chat_media_insert_auth') then
    create policy chat_media_insert_auth on storage.objects
      for insert to authenticated
      with check (bucket_id = 'chat-media');
  end if;

  if not exists (select 1 from pg_policies where policyname='chat_media_select_all') then
    create policy chat_media_select_all on storage.objects
      for select to public
      using (bucket_id = 'chat-media');
  end if;

  if not exists (select 1 from pg_policies where policyname='chat_media_delete_own') then
    create policy chat_media_delete_own on storage.objects
      for delete to authenticated
      using (bucket_id = 'chat-media' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
end $$;


-- -----------------------------------------------------------------------------
-- 3. SÉCURITÉ RLS POUR LES MESSAGES ET CONVERSATIONS (Fix "Erreur envoi")
-- -----------------------------------------------------------------------------
alter table public.messages enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;

do $$ begin
  -- Messages : Lecture par les utilisateurs connectés
  if not exists (select 1 from pg_policies where policyname='messages_select_auth') then
    create policy messages_select_auth on public.messages
      for select to authenticated using (true);
  end if;

  -- Messages : Insertion autorisée si sender_id = auth.uid()
  if not exists (select 1 from pg_policies where policyname='messages_insert_sender') then
    create policy messages_insert_sender on public.messages
      for insert to authenticated with check (auth.uid() = sender_id);
  end if;

  -- Messages : Mise à jour par l'auteur ou pour markAsRead
  if not exists (select 1 from pg_policies where policyname='messages_update_auth') then
    create policy messages_update_auth on public.messages
      for update to authenticated using (true) with check (true);
  end if;

  -- Messages : Suppression par l'auteur
  if not exists (select 1 from pg_policies where policyname='messages_delete_sender') then
    create policy messages_delete_sender on public.messages
      for delete to authenticated using (auth.uid() = sender_id);
  end if;

  -- Conversations
  if not exists (select 1 from pg_policies where policyname='conversations_select_all') then
    create policy conversations_select_all on public.conversations
      for select to authenticated using (true);
  end if;
  if not exists (select 1 from pg_policies where policyname='conversations_insert_all') then
    create policy conversations_insert_all on public.conversations
      for insert to authenticated with check (true);
  end if;
  if not exists (select 1 from pg_policies where policyname='conversations_update_all') then
    create policy conversations_update_all on public.conversations
      for update to authenticated using (true) with check (true);
  end if;

  -- Participants
  if not exists (select 1 from pg_policies where policyname='participants_all') then
    create policy participants_all on public.conversation_participants
      for all to authenticated using (true) with check (true);
  end if;
end $$;


-- -----------------------------------------------------------------------------
-- 4. SÉCURITÉ RLS POUR LE PORTEFEUILLE (Wallet)
-- -----------------------------------------------------------------------------
alter table public.wallet_balances enable row level security;
alter table public.wallet_transactions enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname='wallet_balances_all_own') then
    create policy wallet_balances_all_own on public.wallet_balances
      for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;

  if not exists (select 1 from pg_policies where policyname='wallet_tx_all_own') then
    create policy wallet_tx_all_own on public.wallet_transactions
      for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
end $$;


-- -----------------------------------------------------------------------------
-- 5. TABLE CONTACT_REQUESTS (Pour les demandes de contacts)
-- -----------------------------------------------------------------------------
create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references public.profiles(id) on delete cascade,
  to_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique(from_user_id, to_user_id)
);

alter table public.contact_requests enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname='contact_requests_select') then
    create policy contact_requests_select on public.contact_requests
      for select to authenticated using (auth.uid() = from_user_id or auth.uid() = to_user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname='contact_requests_insert') then
    create policy contact_requests_insert on public.contact_requests
      for insert to authenticated with check (auth.uid() = from_user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname='contact_requests_update') then
    create policy contact_requests_update on public.contact_requests
      for update to authenticated using (auth.uid() = to_user_id or auth.uid() = from_user_id)
      with check (auth.uid() = to_user_id or auth.uid() = from_user_id);
  end if;
end $$;

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
  return to_jsonb(r);
end;
$$;

grant execute on function public.accept_contact_request(uuid) to authenticated;


-- -----------------------------------------------------------------------------
-- 6. ACTIVATION DU TEMPS RÉEL (Supabase Realtime)
-- -----------------------------------------------------------------------------
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when others then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.conversations;
exception when others then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.contact_requests;
exception when others then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.wallet_balances;
exception when others then null;
end $$;
