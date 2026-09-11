-- =============================================================================
-- ChatMe — Fix Supabase BLOQUANTS complet (à exécuter UNE FOIS dans SQL Editor)
-- Consolide 001..005 + ALL_FIXES + manques identifiés (wallet, profiles, realtime, storage)
-- Testé : supabase 2026-09-10 — exécutable idempotent (IF NOT EXISTS / ON CONFLICT)
-- =============================================================================

-- 1) EXTENSIONS
create extension if not exists "pgcrypto";

-- 2) FIX mark_messages_as_read (bug 42702 ambiguous + 42P13 rename)
-- Supprime l'ancienne signature (conversation_id, message_id) avant de recréer avec p_*
drop function if exists public.mark_messages_as_read(uuid,uuid);
create function public.mark_messages_as_read(p_conversation_id uuid, p_message_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_user_id uuid := auth.uid(); begin
  if v_user_id is null then raise exception 'Non authentifié'; end if;
  update public.conversation_participants set last_read_message_id = p_message_id
    where conversation_participants.conversation_id = p_conversation_id and conversation_participants.user_id = v_user_id;
  update public.messages set status='read'
    where messages.conversation_id = p_conversation_id and messages.sender_id != v_user_id
      and messages.created_at <= (select created_at from public.messages where id=p_message_id)
      and messages.status != 'read';
end; $$;
grant execute on function public.mark_messages_as_read(uuid,uuid) to authenticated;

-- 3) BUCKET chat-media (privé, signedUrl 7j côté app)
insert into storage.buckets (id,name,public) values ('chat-media','chat-media', false)
  on conflict (id) do update set public=false;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='chat_media_insert_own') then
    create policy chat_media_insert_own on storage.objects for insert to authenticated
      with check (bucket_id='chat-media' and (storage.foldername(name))[1]=auth.uid()::text); end if;
  if not exists (select 1 from pg_policies where policyname='chat_media_select_participant') then
    create policy chat_media_select_participant on storage.objects for select to authenticated using (bucket_id='chat-media'); end if;
  if not exists (select 1 from pg_policies where policyname='chat_media_delete_own') then
    create policy chat_media_delete_own on storage.objects for delete to authenticated using (bucket_id='chat-media' and (storage.foldername(name))[1]=auth.uid()::text); end if;
  if not exists (select 1 from pg_policies where policyname='chat_media_update_own') then
    create policy chat_media_update_own on storage.objects for update to authenticated using (bucket_id='chat-media' and (storage.foldername(name))[1]=auth.uid()::text); end if;
end $$;

-- 4) PROFILES — ajouter fcm_token + RLS
alter table public.profiles add column if not exists fcm_token text;
alter table public.profiles add column if not exists updated_at timestamptz default now();
alter table public.profiles enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='profiles_select_own_or_participant') then
    create policy profiles_select_own_or_participant on public.profiles for select to authenticated using (true); end if;
  if not exists (select 1 from pg_policies where policyname='profiles_insert_own') then
    create policy profiles_insert_own on public.profiles for insert to authenticated with check (auth.uid()=id); end if;
  if not exists (select 1 from pg_policies where policyname='profiles_update_own') then
    create policy profiles_update_own on public.profiles for update to authenticated using (auth.uid()=id) with check (auth.uid()=id); end if;
end $$;

-- 5) CONVERSATIONS / PARTICIPANTS / MESSAGES RLS (sécurisé mais non bloquant dev)
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='conversations_select_participant') then
    create policy conversations_select_participant on public.conversations for select to authenticated using (
      exists (select 1 from public.conversation_participants where conversation_id=conversations.id and user_id=auth.uid())); end if;
  if not exists (select 1 from pg_policies where policyname='conversations_insert_auth') then
    create policy conversations_insert_auth on public.conversations for insert to authenticated with check (auth.uid()=created_by); end if;
  if not exists (select 1 from pg_policies where policyname='conversations_update_participant') then
    create policy conversations_update_participant on public.conversations for update to authenticated using (
      exists (select 1 from public.conversation_participants where conversation_id=conversations.id and user_id=auth.uid())); end if;
  if not exists (select 1 from pg_policies where policyname='participants_all_own') then
    create policy participants_all_own on public.conversation_participants for all to authenticated using (user_id=auth.uid() or exists (select 1 from public.conversations where id=conversation_id and created_by=auth.uid())) with check (true); end if;
  -- Messages: permissif en dev (true) pour éviter "Erreur envoi" tant que RLS participant non peaufiné
  -- En prod resserrer: with check (auth.uid()=sender_id and exists (... participant))
  if not exists (select 1 from pg_policies where policyname='messages_select_auth') then
    create policy messages_select_auth on public.messages for select to authenticated using (true); end if;
  if not exists (select 1 from pg_policies where policyname='messages_insert_sender') then
    create policy messages_insert_sender on public.messages for insert to authenticated with check (auth.uid()=sender_id); end if;
  if not exists (select 1 from pg_policies where policyname='messages_update_auth') then
    create policy messages_update_auth on public.messages for update to authenticated using (true) with check (true); end if;
  if not exists (select 1 from pg_policies where policyname='messages_delete_sender') then
    create policy messages_delete_sender on public.messages for delete to authenticated using (auth.uid()=sender_id); end if;
end $$;

-- 6) WALLET — tables + RLS + fonctions atomiques
create table if not exists public.wallet_balances (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  balance_cents int not null default 0 check (balance_cents >=0),
  updated_at timestamptz not null default now()
);
create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  amount_cents int not null,
  status text not null default 'completed' check (status in ('pending','completed','failed')),
  created_at timestamptz not null default now()
);
create index if not exists idx_wallet_tx_user_created on public.wallet_transactions(user_id, created_at desc);
alter table public.wallet_balances enable row level security;
alter table public.wallet_transactions enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='wallet_balances_all_own') then
    create policy wallet_balances_all_own on public.wallet_balances for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id); end if;
  if not exists (select 1 from pg_policies where policyname='wallet_tx_all_own') then
    create policy wallet_tx_all_own on public.wallet_transactions for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id); end if;
end $$;

-- Fonctions wallet atomiques (idempotentes, sécurité definer)
create or replace function public.wallet_deposit(p_amount int, p_label text)
returns int language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_new int; begin
  if v_uid is null then raise exception 'Non authentifié'; end if;
  if p_amount <=0 then raise exception 'Montant invalide'; end if;
  insert into public.wallet_balances(user_id,balance_cents,updated_at) values (v_uid,p_amount,now())
    on conflict (user_id) do update set balance_cents=wallet_balances.balance_cents + EXCLUDED.balance_cents, updated_at=now()
    returning balance_cents into v_new;
  -- fallback si insert déjà existait mais returning null
  if v_new is null then select balance_cents into v_new from public.wallet_balances where user_id=v_uid; end if;
  insert into public.wallet_transactions(user_id,label,amount_cents,status) values (v_uid,p_label,p_amount,'completed');
  return v_new;
end; $$;
grant execute on function public.wallet_deposit(int,text) to authenticated;

create or replace function public.wallet_withdraw(p_amount int, p_label text)
returns int language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_bal int; v_new int; begin
  if v_uid is null then raise exception 'Non authentifié'; end if;
  if p_amount <=0 then raise exception 'Montant invalide'; end if;
  select balance_cents into v_bal from public.wallet_balances where user_id=v_uid for update;
  if v_bal is null then v_bal:=0; end if;
  if v_bal < p_amount then raise exception 'Solde insuffisant'; end if;
  update public.wallet_balances set balance_cents=balance_cents - p_amount, updated_at=now() where user_id=v_uid returning balance_cents into v_new;
  if v_new is null then -- ligne n'existait pas, créer à 0 puis retry
    insert into public.wallet_balances(user_id,balance_cents) values (v_uid,0) on conflict do nothing;
    raise exception 'Solde insuffisant';
  end if;
  insert into public.wallet_transactions(user_id,label,amount_cents,status) values (v_uid,p_label,-p_amount,'completed');
  return v_new;
end; $$;
grant execute on function public.wallet_withdraw(int,text) to authenticated;

create or replace function public.wallet_transfer(p_dest_user_id uuid, p_amount int)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_bal int; v_new int; v_dest_bal int; begin
  if v_uid is null then raise exception 'Non authentifié'; end if;
  if p_dest_user_id = v_uid then raise exception 'Destinataire invalide'; end if;
  if p_amount <=0 then raise exception 'Montant invalide'; end if;
  if not exists (select 1 from public.profiles where id=p_dest_user_id) then raise exception 'Destinataire introuvable'; end if;
  select balance_cents into v_bal from public.wallet_balances where user_id=v_uid for update;
  if v_bal is null or v_bal < p_amount then raise exception 'Solde insuffisant'; end if;
  update public.wallet_balances set balance_cents=balance_cents - p_amount, updated_at=now() where user_id=v_uid returning balance_cents into v_new;
  insert into public.wallet_balances(user_id,balance_cents,updated_at) values (p_dest_user_id,p_amount,now())
    on conflict (user_id) do update set balance_cents=wallet_balances.balance_cents + p_amount, updated_at=now() returning balance_cents into v_dest_bal;
  -- si dest n'existait pas, v_dest_bal est null mais insert a marché
  if v_dest_bal is null then select balance_cents into v_dest_bal from public.wallet_balances where user_id=p_dest_user_id; end if;
  insert into public.wallet_transactions(user_id,label,amount_cents,status) values (v_uid,'Virement envoyé',-p_amount,'completed');
  insert into public.wallet_transactions(user_id,label,amount_cents,status) values (p_dest_user_id,'Virement reçu',p_amount,'completed');
  return jsonb_build_object('from_balance',v_new,'to_balance',v_dest_bal);
end; $$;
grant execute on function public.wallet_transfer(uuid,int) to authenticated;

create or replace function public.get_or_create_direct_conversation(other_user_id uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_conv uuid; begin
  if v_uid is null then raise exception 'Non authentifié'; end if;
  if other_user_id is null or other_user_id=v_uid then raise exception 'Utilisateur invalide'; end if;
  -- chercher conv directe existante (2 participants, type direct)
  select c.id into v_conv from public.conversations c
    join public.conversation_participants p1 on p1.conversation_id=c.id and p1.user_id=v_uid
    join public.conversation_participants p2 on p2.conversation_id=c.id and p2.user_id=other_user_id
    where c.type='direct' limit 1;
  if v_conv is not null then return v_conv; end if;
  insert into public.conversations(type,created_by) values ('direct',v_uid) returning id into v_conv;
  insert into public.conversation_participants(conversation_id,user_id,role) values (v_conv,v_uid,'admin'),(v_conv,other_user_id,'member');
  return v_conv;
end; $$;
grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;

-- 7) CONTACTS
create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references public.profiles(id) on delete cascade,
  to_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  created_at timestamptz not null default now(), responded_at timestamptz,
  unique(from_user_id,to_user_id)
);
create index if not exists idx_contact_requests_to on public.contact_requests(to_user_id,status);
create index if not exists idx_contact_requests_from on public.contact_requests(from_user_id,status);
alter table public.contact_requests enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='contact_requests_select_own') then
    create policy contact_requests_select_own on public.contact_requests for select using (auth.uid()=from_user_id or auth.uid()=to_user_id); end if;
  if not exists (select 1 from pg_policies where policyname='contact_requests_insert_own') then
    create policy contact_requests_insert_own on public.contact_requests for insert with check (auth.uid()=from_user_id); end if;
  if not exists (select 1 from pg_policies where policyname='contact_requests_update_both') then
    create policy contact_requests_update_both on public.contact_requests for update using (auth.uid()=to_user_id or auth.uid()=from_user_id) with check (auth.uid()=to_user_id or auth.uid()=from_user_id); end if;
  if not exists (select 1 from pg_policies where policyname='contact_requests_delete_own') then
    create policy contact_requests_delete_own on public.contact_requests for delete using (auth.uid()=from_user_id or auth.uid()=to_user_id); end if;
end $$;
create or replace function public.accept_contact_request(req_id uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare r record; begin
  if auth.uid() is null then raise exception 'Non authentifié'; end if;
  select * into r from public.contact_requests where id=req_id and to_user_id=auth.uid() and status='pending';
  if not found then raise exception 'Demande introuvable ou déjà traitée'; end if;
  update public.contact_requests set status='accepted', responded_at=now() where id=req_id; return to_jsonb(r);
end; $$;
grant execute on function public.accept_contact_request(uuid) to authenticated;

-- 8) STATUTS / MOMENTS
create table if not exists public.statuses (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('text','image')), text text, media_path text,
  duration_minutes int not null default 1440, created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index if not exists idx_statuses_user on public.statuses(user_id,expires_at);
create index if not exists idx_statuses_expires on public.statuses(expires_at);
alter table public.statuses enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='statuses_select_valid') then create policy statuses_select_valid on public.statuses for select using (expires_at > now()); end if;
  if not exists (select 1 from pg_policies where policyname='statuses_insert_own') then create policy statuses_insert_own on public.statuses for insert with check (auth.uid()=user_id); end if;
  if not exists (select 1 from pg_policies where policyname='statuses_delete_own') then create policy statuses_delete_own on public.statuses for delete using (auth.uid()=user_id); end if;
  if not exists (select 1 from pg_policies where policyname='statuses_update_own') then create policy statuses_update_own on public.statuses for update using (auth.uid()=user_id) with check (auth.uid()=user_id); end if;
end $$;
create table if not exists public.moments (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  content text, image_url text, visibility text default 'public', created_at timestamptz not null default now()
);
alter table public.moments enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where policyname='moments_select_all') then create policy moments_select_all on public.moments for select using (true); end if;
  if not exists (select 1 from pg_policies where policyname='moments_insert_own') then create policy moments_insert_own on public.moments for insert with check (auth.uid()=user_id); end if;
  if not exists (select 1 from pg_policies where policyname='moments_delete_own') then create policy moments_delete_own on public.moments for delete using (auth.uid()=user_id); end if;
end $$;

-- 9) REALTIME
do $$ begin alter publication supabase_realtime add table public.messages; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table public.conversations; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table public.conversation_participants; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table public.contact_requests; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table public.wallet_balances; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table public.wallet_transactions; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table public.statuses; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table public.moments; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table public.profiles; exception when others then null; end $$;
