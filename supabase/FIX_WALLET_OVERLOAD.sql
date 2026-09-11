-- =========================================================================
-- FIX AMBIGUÏTÉ WALLET (PGRST203) - Résout le conflit bigint vs integer
-- À copier-coller et exécuter dans l'éditeur SQL de Supabase
-- =========================================================================

-- 1. Supprimer toutes les anciennes versions en doublon
drop function if exists public.wallet_deposit(bigint, text);
drop function if exists public.wallet_deposit(integer, text);
drop function if exists public.wallet_deposit(int, text);

drop function if exists public.wallet_withdraw(bigint, text);
drop function if exists public.wallet_withdraw(integer, text);
drop function if exists public.wallet_withdraw(int, text);

drop function if exists public.wallet_transfer(uuid, bigint);
drop function if exists public.wallet_transfer(uuid, integer);
drop function if exists public.wallet_transfer(uuid, int);

-- 2. S'assurer que les tables et RLS existent
create table if not exists public.wallet_balances (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  balance_cents int not null default 0 check (balance_cents >= 0),
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
    create policy wallet_balances_all_own on public.wallet_balances for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id); 
  end if;
  if not exists (select 1 from pg_policies where policyname='wallet_tx_all_own') then
    create policy wallet_tx_all_own on public.wallet_transactions for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id); 
  end if;
end $$;

-- 3. Recréer la fonction atomique wallet_deposit (VERSION UNIQUE)
create or replace function public.wallet_deposit(p_amount int, p_label text)
returns int language plpgsql security definer set search_path=public as $$
declare 
  v_uid uuid := auth.uid(); 
  v_new int; 
begin
  if v_uid is null then raise exception 'Non authentifié'; end if;
  if p_amount <= 0 then raise exception 'Montant invalide'; end if;

  insert into public.wallet_balances(user_id, balance_cents, updated_at) 
  values (v_uid, p_amount, now())
  on conflict (user_id) do update 
    set balance_cents = wallet_balances.balance_cents + EXCLUDED.balance_cents, 
        updated_at = now()
  returning balance_cents into v_new;

  if v_new is null then 
    select balance_cents into v_new from public.wallet_balances where user_id = v_uid; 
  end if;

  insert into public.wallet_transactions(user_id, label, amount_cents, status) 
  values (v_uid, p_label, p_amount, 'completed');

  return v_new;
end; $$;

grant execute on function public.wallet_deposit(int, text) to authenticated;

-- 4. Recréer la fonction atomique wallet_withdraw (VERSION UNIQUE)
create or replace function public.wallet_withdraw(p_amount int, p_label text)
returns int language plpgsql security definer set search_path=public as $$
declare 
  v_uid uuid := auth.uid(); 
  v_bal int; 
  v_new int; 
begin
  if v_uid is null then raise exception 'Non authentifié'; end if;
  if p_amount <= 0 then raise exception 'Montant invalide'; end if;

  select balance_cents into v_bal from public.wallet_balances where user_id = v_uid for update;
  if v_bal is null then v_bal := 0; end if;
  if v_bal < p_amount then raise exception 'Solde insuffisant'; end if;

  update public.wallet_balances 
  set balance_cents = balance_cents - p_amount, updated_at = now() 
  where user_id = v_uid 
  returning balance_cents into v_new;

  insert into public.wallet_transactions(user_id, label, amount_cents, status) 
  values (v_uid, p_label, -p_amount, 'completed');

  return v_new;
end; $$;

grant execute on function public.wallet_withdraw(int, text) to authenticated;

-- 5. Recréer la fonction atomique wallet_transfer (VERSION UNIQUE)
create or replace function public.wallet_transfer(p_dest_user_id uuid, p_amount int)
returns jsonb language plpgsql security definer set search_path=public as $$
declare 
  v_uid uuid := auth.uid(); 
  v_bal int; 
  v_new int; 
  v_dest_bal int; 
begin
  if v_uid is null then raise exception 'Non authentifié'; end if;
  if p_dest_user_id = v_uid then raise exception 'Destinataire invalide'; end if;
  if p_amount <= 0 then raise exception 'Montant invalide'; end if;
  if not exists (select 1 from public.profiles where id = p_dest_user_id) then 
    raise exception 'Destinataire introuvable'; 
  end if;

  select balance_cents into v_bal from public.wallet_balances where user_id = v_uid for update;
  if v_bal is null or v_bal < p_amount then raise exception 'Solde insuffisant'; end if;

  update public.wallet_balances 
  set balance_cents = balance_cents - p_amount, updated_at = now() 
  where user_id = v_uid 
  returning balance_cents into v_new;

  insert into public.wallet_balances(user_id, balance_cents, updated_at) 
  values (p_dest_user_id, p_amount, now())
  on conflict (user_id) do update 
    set balance_cents = wallet_balances.balance_cents + p_amount, updated_at = now() 
  returning balance_cents into v_dest_bal;

  if v_dest_bal is null then 
    select balance_cents into v_dest_bal from public.wallet_balances where user_id = p_dest_user_id; 
  end if;

  insert into public.wallet_transactions(user_id, label, amount_cents, status) 
  values (v_uid, 'Virement envoyé', -p_amount, 'completed');

  insert into public.wallet_transactions(user_id, label, amount_cents, status) 
  values (p_dest_user_id, 'Virement reçu', p_amount, 'completed');

  return jsonb_build_object('from_balance', v_new, 'to_balance', v_dest_bal);
end; $$;

grant execute on function public.wallet_transfer(uuid, int) to authenticated;

-- 6. Publication Realtime pour synchronisation en direct
do $$ begin alter publication supabase_realtime add table public.wallet_balances; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table public.wallet_transactions; exception when others then null; end $$;
