-- 003_wallet_rls_check.sql - Vérifie que les RLS wallet existent (déjà constaté: fonctions wallet_deposit/withdraw existent et exigent auth)

-- S'assurer que wallet_balances et wallet_transactions ont RLS + policies
alter table public.wallet_balances enable row level security;
alter table public.wallet_transactions enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where policyname='wallet_balances_select_own') then
    create policy wallet_balances_select_own on public.wallet_balances for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname='wallet_balances_upsert_own') then
    create policy wallet_balances_upsert_own on public.wallet_balances for insert with check (auth.uid() = user_id);
    create policy wallet_balances_update_own on public.wallet_balances for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname='wallet_tx_select_own') then
    create policy wallet_tx_select_own on public.wallet_transactions for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where policyname='wallet_tx_insert_own') then
    create policy wallet_tx_insert_own on public.wallet_transactions for insert with check (auth.uid() = user_id);
  end if;
end $$;

-- Vérifier RLS messages / conversations (cause fréquente de "Erreur envoi message")
-- L'utilisateur doit être participant pour insérer/lire
-- Si les policies ci-dessous manquent, l'envoi message renvoie 42501 ou RLS violation

-- Exemple attendu (à adapter si vos policies ont un autre nom):
-- messages: select/insert où l'utilisateur est participant ou sender
-- Si vous voyez "new row violates row-level security policy for table messages" lors d'un send, exécutez:
-- create policy messages_insert_participant on public.messages for insert with check (
--   auth.uid() = sender_id and exists (select 1 from public.conversation_participants where conversation_id = messages.conversation_id and user_id = auth.uid())
-- );
