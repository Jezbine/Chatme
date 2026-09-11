-- =============================================================================
-- ChatMe — FIX RÉCURSION INFINIE conversation_participants (42P17)
-- Erreur: "infinite recursion detected in policy for relation conversation_participants"
-- Cause: SUPABASE_BLOQUANTS_FIX.sql a créé 2 policies qui se référencent mutuellement:
--   conversations SELECT: exists (select 1 from conversation_participants ...)
--   participants ALL:    exists (select 1 from conversations ...)
--   → chaque SELECT déclenche l'autre RLS → boucle infinie
-- Fix: helper SECURITY DEFINER qui bypass RLS + recréation policies sans récursion
-- À exécuter DANS Supabase Dashboard > SQL Editor > New query > RUN
-- Idempotent, à lancer UNE FOIS
-- =============================================================================

-- 1) Nettoyer les policies récursives (si elles existent)
drop policy if exists "conversations_select_participant" on public.conversations;
drop policy if exists "conversations_update_participant" on public.conversations;
drop policy if exists "participants_all_own" on public.conversation_participants;
-- Anciennes policies permissives de ALL_FIXES.sql (pour éviter doublons)
drop policy if exists "conversations_select_all" on public.conversations;
drop policy if exists "conversations_insert_all" on public.conversations;
drop policy if exists "conversations_update_all" on public.conversations;
drop policy if exists "participants_all" on public.conversation_participants;

-- 2) Helper SECURITY DEFINER : vérifie sans passer par RLS (bypass)
create or replace function public.is_conversation_member(p_conv_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversation_participants
    where conversation_id = p_conv_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.is_conversation_creator(p_conv_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversations
    where id = p_conv_id
      and created_by = auth.uid()
  );
$$;

grant execute on function public.is_conversation_member(uuid) to authenticated;
grant execute on function public.is_conversation_creator(uuid) to authenticated;

-- 3) Recréer les policies SANS récursion (utilisent les helpers)
-- Nettoyer aussi les cibles de ce fix si déjà créées lors d'un run partiel
drop policy if exists "conversations_select_member" on public.conversations;
drop policy if exists "conversations_insert_auth" on public.conversations;
drop policy if exists "conversations_update_member" on public.conversations;
drop policy if exists "participants_select_own_or_member" on public.conversation_participants;
drop policy if exists "participants_insert_member" on public.conversation_participants;
drop policy if exists "participants_update_own" on public.conversation_participants;
drop policy if exists "participants_delete_own" on public.conversation_participants;
drop policy if exists "messages_select_member" on public.messages;
drop policy if exists "messages_insert_member" on public.messages;
drop policy if exists "messages_update_member" on public.messages;
drop policy if exists "messages_delete_sender" on public.messages;

-- Conversations : visible si on est membre OU créateur
create policy conversations_select_member
  on public.conversations for select to authenticated
  using (
    created_by = auth.uid()
    or public.is_conversation_member(id)
  );

create policy conversations_insert_auth
  on public.conversations for insert to authenticated
  with check (auth.uid() = created_by);

create policy conversations_update_member
  on public.conversations for update to authenticated
  using (public.is_conversation_member(id) or created_by = auth.uid())
  with check (public.is_conversation_member(id) or created_by = auth.uid());

-- Participants : on voit/gère ses propres lignes, et le créateur de la conv peut tout voir
-- IMPORTANT: ne plus faire de sous-requête sur conversations sans helper
create policy participants_select_own_or_member
  on public.conversation_participants for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_conversation_member(conversation_id)
    or public.is_conversation_creator(conversation_id)
  );

create policy participants_insert_member
  on public.conversation_participants for insert to authenticated
  with check (
    -- on peut s'ajouter soi-même si la conv existe et on est créateur, ou si on y est déjà invité
    user_id = auth.uid()
    or public.is_conversation_creator(conversation_id)
    or public.is_conversation_member(conversation_id)
  );

create policy participants_update_own
  on public.conversation_participants for update to authenticated
  using (user_id = auth.uid() or public.is_conversation_creator(conversation_id))
  with check (user_id = auth.uid() or public.is_conversation_creator(conversation_id));

create policy participants_delete_own
  on public.conversation_participants for delete to authenticated
  using (user_id = auth.uid() or public.is_conversation_creator(conversation_id));

-- 4) Messages : garder permissif en dev (true) mais sécurisé via sender check
-- Pas de récursion ici
drop policy if exists "messages_select_auth" on public.messages;
drop policy if exists "messages_insert_sender" on public.messages;
drop policy if exists "messages_update_auth" on public.messages;
drop policy if exists "messages_delete_sender" on public.messages;

create policy messages_select_member
  on public.messages for select to authenticated
  using (public.is_conversation_member(conversation_id));

create policy messages_insert_member
  on public.messages for insert to authenticated
  with check (
    auth.uid() = sender_id
    and public.is_conversation_member(conversation_id)
  );

create policy messages_update_member
  on public.messages for update to authenticated
  using (public.is_conversation_member(conversation_id))
  with check (public.is_conversation_member(conversation_id));

create policy messages_delete_sender
  on public.messages for delete to authenticated
  using (auth.uid() = sender_id);

-- 5) Vérification
-- Après RUN, tester dans SQL Editor (en tant que authenticated via "Run as" ou avec jwt) :
-- select * from public.conversation_participants limit 1; -- ne doit plus donner 42P17
-- Si erreur persiste, variante DEV ultra-permissive (décommenter) :
-- drop policy if exists "conversations_select_member" on public.conversations;
-- create policy conversations_select_member on public.conversations for select to authenticated using (true);
-- drop policy if exists "participants_select_own_or_member" on public.conversation_participants;
-- create policy participants_select_own_or_member on public.conversation_participants for select to authenticated using (true);
-- drop policy if exists "messages_select_member" on public.messages;
-- create policy messages_select_member on public.messages for select to authenticated using (true);
